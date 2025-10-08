-- approve_user_nft関数の完全修正版
-- ON CONFLICT句でEXCLUDEDを使用してuser_idの曖昧さを解消

DROP FUNCTION IF EXISTS approve_user_nft(TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION approve_user_nft(
    p_purchase_id TEXT,
    p_admin_email TEXT,
    p_admin_notes TEXT DEFAULT NULL
)
RETURNS TABLE(
    status TEXT,
    message TEXT,
    user_id TEXT,
    nft_count INTEGER,
    success BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_purchase_id UUID;
    v_user_id TEXT;
    v_nft_quantity INTEGER;
    v_amount_usd NUMERIC;
    v_is_approved BOOLEAN;
    v_is_auto BOOLEAN;
    v_user_exists BOOLEAN;
    v_next_sequence INTEGER;
    v_nft_created INTEGER := 0;
BEGIN
    -- UUIDに変換
    BEGIN
        v_purchase_id := p_purchase_id::UUID;
    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            '無効な購入IDです'::TEXT,
            NULL::TEXT,
            0::INTEGER,
            false::BOOLEAN;
        RETURN;
    END;

    -- 購入レコードを取得
    SELECT
        p.user_id,
        p.nft_quantity,
        p.amount_usd,
        p.admin_approved,
        p.is_auto_purchase
    INTO
        v_user_id,
        v_nft_quantity,
        v_amount_usd,
        v_is_approved,
        v_is_auto
    FROM purchases p
    WHERE p.id = v_purchase_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            '購入レコードが見つかりません'::TEXT,
            NULL::TEXT,
            0::INTEGER,
            false::BOOLEAN;
        RETURN;
    END IF;

    -- 既に承認済みかチェック
    IF v_is_approved THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            'この購入は既に承認済みです'::TEXT,
            v_user_id,
            0::INTEGER,
            false::BOOLEAN;
        RETURN;
    END IF;

    -- 自動購入は承認対象外
    IF v_is_auto THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            '自動購入は手動承認できません'::TEXT,
            v_user_id,
            0::INTEGER,
            false::BOOLEAN;
        RETURN;
    END IF;

    -- ユーザーが存在するか確認
    SELECT EXISTS(
        SELECT 1 FROM users u WHERE u.user_id = v_user_id
    ) INTO v_user_exists;

    IF NOT v_user_exists THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            'ユーザーが見つかりません'::TEXT,
            v_user_id,
            0::INTEGER,
            false::BOOLEAN;
        RETURN;
    END IF;

    -- 次のNFTシーケンス番号を取得
    SELECT COALESCE(MAX(nm.nft_sequence), 0) + 1
    INTO v_next_sequence
    FROM nft_master nm
    WHERE nm.user_id = v_user_id;

    -- NFT数分だけnft_masterレコードを作成
    FOR i IN 1..v_nft_quantity LOOP
        INSERT INTO nft_master (
            user_id,
            nft_sequence,
            nft_type,
            nft_value,
            acquired_date,
            created_at,
            updated_at
        )
        VALUES (
            v_user_id,
            v_next_sequence + i - 1,
            'manual',
            1100.00,
            NOW()::DATE,
            NOW(),
            NOW()
        );
        v_nft_created := v_nft_created + 1;
    END LOOP;

    -- purchasesテーブルを更新
    UPDATE purchases
    SET
        admin_approved = true,
        admin_approved_at = NOW(),
        admin_approved_by = p_admin_email,
        admin_notes = COALESCE(p_admin_notes, '承認済み'),
        payment_status = 'completed'
    WHERE id = v_purchase_id;

    -- usersテーブルを更新
    UPDATE users
    SET
        total_purchases = total_purchases + v_amount_usd,
        updated_at = NOW()
    WHERE user_id = v_user_id;

    -- ★★★ 修正: affiliate_cycleをUPSERT（EXCLUDEDを使用） ★★★
    INSERT INTO affiliate_cycle (
        user_id,
        manual_nft_count,
        auto_nft_count,
        total_nft_count,
        cum_usdt,
        available_usdt,
        phase,
        cycle_number,
        created_at,
        last_updated
    )
    VALUES (
        v_user_id,
        v_nft_quantity,
        0,
        v_nft_quantity,
        0,
        0,
        'USDT',
        1,
        NOW(),
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        manual_nft_count = (SELECT manual_nft_count FROM affiliate_cycle WHERE affiliate_cycle.user_id = EXCLUDED.user_id) + EXCLUDED.manual_nft_count,
        total_nft_count = (SELECT total_nft_count FROM affiliate_cycle WHERE affiliate_cycle.user_id = EXCLUDED.user_id) + EXCLUDED.total_nft_count,
        last_updated = EXCLUDED.last_updated;

    -- 成功レスポンス
    RETURN QUERY SELECT
        'SUCCESS'::TEXT,
        FORMAT('購入を承認しました（NFT %s枚をnft_masterに作成）', v_nft_created)::TEXT,
        v_user_id,
        v_nft_created::INTEGER,
        true::BOOLEAN;

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT
        'ERROR'::TEXT,
        FORMAT('エラーが発生しました: %s', SQLERRM)::TEXT,
        NULL::TEXT,
        0::INTEGER,
        false::BOOLEAN;
END;
$function$;

GRANT EXECUTE ON FUNCTION approve_user_nft(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION approve_user_nft(TEXT, TEXT, TEXT) TO anon;

-- テスト実行
SELECT * FROM approve_user_nft(
    'ecee97ac-0519-4a41-b53e-03e05d033d9c',
    'test@admin.com',
    'テスト承認'
);
