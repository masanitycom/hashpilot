-- ========================================
-- approve_user_nft関数の曖昧なuser_id参照を修正
-- ========================================
-- エラー: column reference "user_id" is ambiguous
-- 原因: ON CONFLICT句でuser_idがどのテーブルか不明確

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
SET search_path = public
AS $$
DECLARE
    v_purchase RECORD;
    v_user_exists BOOLEAN;
    v_next_sequence INTEGER;
    v_nft_created INTEGER := 0;
BEGIN
    -- 購入レコードを取得
    SELECT
        p.id,
        p.user_id,
        p.nft_quantity,
        p.amount_usd,
        p.admin_approved,
        p.is_auto_purchase
    INTO v_purchase
    FROM purchases p
    WHERE p.id::TEXT = p_purchase_id;

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
    IF v_purchase.admin_approved THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            'この購入は既に承認済みです'::TEXT,
            v_purchase.user_id,
            0::INTEGER,
            false::BOOLEAN;
        RETURN;
    END IF;

    -- 自動購入は承認対象外
    IF v_purchase.is_auto_purchase THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            '自動購入は手動承認できません'::TEXT,
            v_purchase.user_id,
            0::INTEGER,
            false::BOOLEAN;
        RETURN;
    END IF;

    -- ユーザーが存在するか確認
    SELECT EXISTS(SELECT 1 FROM users u WHERE u.user_id = v_purchase.user_id)
    INTO v_user_exists;

    IF NOT v_user_exists THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            'ユーザーが見つかりません'::TEXT,
            v_purchase.user_id,
            0::INTEGER,
            false::BOOLEAN;
        RETURN;
    END IF;

    -- nft_masterテーブルにNFTレコードを作成
    SELECT COALESCE(MAX(nm.nft_sequence), 0) + 1
    INTO v_next_sequence
    FROM nft_master nm
    WHERE nm.user_id = v_purchase.user_id;

    -- NFT数分だけnft_masterレコードを作成
    FOR i IN 1..v_purchase.nft_quantity LOOP
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
            v_purchase.user_id,
            v_next_sequence + i - 1,
            'manual',
            1000.00,
            NOW()::DATE,
            NOW(),
            NOW()
        );
        v_nft_created := v_nft_created + 1;
    END LOOP;

    -- purchasesテーブルを更新（承認済みにする）
    UPDATE purchases
    SET
        admin_approved = true,
        admin_approved_at = NOW(),
        admin_approved_by = p_admin_email,
        admin_notes = COALESCE(p_admin_notes, '承認済み'),
        payment_status = 'completed'
    WHERE id::TEXT = p_purchase_id;

    -- usersテーブルを更新
    UPDATE users u
    SET
        total_purchases = u.total_purchases + v_purchase.amount_usd,
        updated_at = NOW()
    WHERE u.user_id = v_purchase.user_id;

    -- affiliate_cycleテーブルを更新（NFTカウント）
    -- ★★★ 修正: ON CONFLICT句でテーブル名を明示 ★★★
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
        v_purchase.user_id,
        v_purchase.nft_quantity,
        0,
        v_purchase.nft_quantity,
        0,
        0,
        'USDT',
        1,
        NOW(),
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        manual_nft_count = EXCLUDED.manual_nft_count + affiliate_cycle.manual_nft_count,
        total_nft_count = EXCLUDED.total_nft_count + affiliate_cycle.total_nft_count,
        last_updated = NOW();

    -- 成功レスポンス
    RETURN QUERY SELECT
        'SUCCESS'::TEXT,
        FORMAT('購入を承認しました（NFT %s枚をnft_masterに作成）', v_nft_created)::TEXT,
        v_purchase.user_id,
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
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION approve_user_nft(TEXT, TEXT, TEXT) TO authenticated;

-- 完了メッセージ
SELECT '✅ approve_user_nft関数の曖昧なuser_id参照を修正しました' as status;
