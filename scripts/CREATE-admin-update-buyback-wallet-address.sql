-- =====================================================================
-- 買い取り申請の送金先アドレスを管理画面から変更できるようにする
-- 作成日: 2026-08-07
-- =====================================================================
--
-- 【背景】
-- ユーザーが買い取り申請(/nft の買取りフォーム)を出した後に
-- 「送金先アドレスを間違えた／変えたい」と連絡してくるケースが多い。
-- これまでは管理画面から直せず、SQLで直接UPDATEするしかなかった。
--
-- 【仕様】
-- - 変更できるのは status = 'pending' の申請のみ（処理済みは変更不可）
-- - wallet_address のみ変更可能。wallet_type（USDT-BEP20 / CoinW）は変更しない
-- - アドレス形式を検証する
--     USDT-BEP20 … 0x + 40桁の16進数
--     CoinW      … 数字のみ(5〜20桁)
-- - 変更履歴は admin_notes への追記と system_logs の両方に残す
-- - users テーブル(coinw_uid / nft_receive_address)は触らない
--   （CoinW UIDの変更には別途 coinw_uid_changes の承認フローがあるため）
--
-- 【実行先】本サイト(soghqozaxfswtxxbgeer) と サブ(ishewpmumgkygayfnlkw) の両方
-- =====================================================================

DROP FUNCTION IF EXISTS admin_update_buyback_wallet_address(UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION admin_update_buyback_wallet_address(
    p_request_id UUID,
    p_wallet_address TEXT,
    p_admin_email TEXT
)
RETURNS TABLE(
    status TEXT,
    message TEXT,
    old_address TEXT,
    new_address TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_request RECORD;
    v_new TEXT;
    v_is_admin BOOLEAN;
BEGIN
    -- ---------------------------------------------------------------
    -- 管理者チェック
    -- admins テーブルに加え、管理画面が直接許可しているメールも通す
    -- （app/admin/buyback/page.tsx の checkAdminAccess と同じ顔ぶれ）
    -- ---------------------------------------------------------------
    SELECT (
        EXISTS (
            SELECT 1 FROM admins a
            WHERE a.email = p_admin_email
              AND COALESCE(a.is_active, TRUE) = TRUE
        )
        OR p_admin_email IN (
            'basarasystems@gmail.com',
            'support@dshsupport.biz',
            'masataka.tak@gmail.com'
        )
    ) INTO v_is_admin;

    IF NOT v_is_admin THEN
        RETURN QUERY SELECT 'ERROR'::TEXT, '管理者権限がありません'::TEXT, NULL::TEXT, NULL::TEXT;
        RETURN;
    END IF;

    -- ---------------------------------------------------------------
    -- 申請の取得
    -- ---------------------------------------------------------------
    SELECT * INTO v_request FROM buyback_requests WHERE id = p_request_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT 'ERROR'::TEXT, '買い取り申請が見つかりません'::TEXT, NULL::TEXT, NULL::TEXT;
        RETURN;
    END IF;

    IF v_request.status <> 'pending' THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            format('この申請は既に処理済み(%s)のため変更できません', v_request.status)::TEXT,
            v_request.wallet_address, NULL::TEXT;
        RETURN;
    END IF;

    -- ---------------------------------------------------------------
    -- 入力検証
    -- ---------------------------------------------------------------
    v_new := BTRIM(COALESCE(p_wallet_address, ''));

    IF v_new = '' THEN
        RETURN QUERY SELECT 'ERROR'::TEXT, '送金先アドレスを入力してください'::TEXT,
            v_request.wallet_address, NULL::TEXT;
        RETURN;
    END IF;

    IF v_request.wallet_type = 'CoinW' THEN
        IF v_new !~ '^[0-9]{5,20}$' THEN
            RETURN QUERY SELECT 'ERROR'::TEXT,
                'CoinW UIDは5〜20桁の数字で入力してください'::TEXT,
                v_request.wallet_address, NULL::TEXT;
            RETURN;
        END IF;
    ELSE
        -- USDT-BEP20（既定）
        IF v_new !~ '^0x[0-9a-fA-F]{40}$' THEN
            RETURN QUERY SELECT 'ERROR'::TEXT,
                'USDT-BEP20アドレスの形式が正しくありません（0x + 16進40桁）'::TEXT,
                v_request.wallet_address, NULL::TEXT;
            RETURN;
        END IF;
    END IF;

    IF v_new = v_request.wallet_address THEN
        RETURN QUERY SELECT 'NO_CHANGE'::TEXT, 'アドレスは変更されていません'::TEXT,
            v_request.wallet_address, v_new;
        RETURN;
    END IF;

    -- ---------------------------------------------------------------
    -- 更新（変更履歴を admin_notes に追記）
    -- ---------------------------------------------------------------
    UPDATE buyback_requests
    SET wallet_address = v_new,
        admin_notes = CONCAT_WS(E'\n',
            NULLIF(BTRIM(COALESCE(admin_notes, '')), ''),
            format('[%s] 送金先アドレス変更: %s → %s (%s)',
                   TO_CHAR(NOW() AT TIME ZONE 'Asia/Tokyo', 'YYYY-MM-DD HH24:MI'),
                   v_request.wallet_address, v_new, p_admin_email)
        ),
        updated_at = NOW()
    WHERE id = p_request_id;

    -- ---------------------------------------------------------------
    -- ログ
    -- ---------------------------------------------------------------
    BEGIN
        INSERT INTO system_logs (log_type, operation, user_id, message, details, created_at)
        VALUES (
            'buyback_wallet_update',
            'admin_update_buyback_wallet_address',
            v_request.user_id,
            format('買い取り申請の送金先アドレスを変更: %s → %s', v_request.wallet_address, v_new),
            jsonb_build_object(
                'request_id',   p_request_id,
                'user_id',      v_request.user_id,
                'email',        v_request.email,
                'wallet_type',  v_request.wallet_type,
                'old_address',  v_request.wallet_address,
                'new_address',  v_new,
                'admin_email',  p_admin_email
            ),
            NOW()
        );
    EXCEPTION WHEN OTHERS THEN
        NULL;  -- ログ失敗で本処理は止めない
    END;

    RETURN QUERY SELECT 'SUCCESS'::TEXT, '送金先アドレスを変更しました'::TEXT,
        v_request.wallet_address, v_new;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_update_buyback_wallet_address(UUID, TEXT, TEXT) TO authenticated;


-- =====================================================================
-- 動作確認
-- =====================================================================
-- 1) 関数が作成されたか
SELECT proname, pg_get_function_identity_arguments(oid) AS args
FROM pg_proc WHERE proname = 'admin_update_buyback_wallet_address';

-- 2) pending の申請を確認
-- SELECT id, user_id, email, wallet_type, wallet_address, status
-- FROM buyback_requests WHERE status = 'pending' ORDER BY request_date DESC;

-- 3) テスト（<request_id> を差し替え）
-- SELECT * FROM admin_update_buyback_wallet_address(
--   '<request_id>'::UUID,
--   '0x0000000000000000000000000000000000000000',
--   'basarasystems@gmail.com'
-- );

-- 4) 変更履歴の確認
-- SELECT admin_notes FROM buyback_requests WHERE id = '<request_id>';
-- SELECT * FROM system_logs WHERE log_type = 'buyback_wallet_update' ORDER BY created_at DESC LIMIT 10;


-- =====================================================================
-- ロールバック
-- =====================================================================
-- DROP FUNCTION IF EXISTS admin_update_buyback_wallet_address(UUID, TEXT, TEXT);
