-- ========================================
-- ON CONFLICT句の完全修正
-- ========================================

DROP FUNCTION IF EXISTS approve_user_nft(TEXT, TEXT, TEXT) CASCADE;

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
    v_target_user_id TEXT;
    v_existing_manual_count INTEGER;
    v_existing_total_count INTEGER;
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

    v_target_user_id := v_purchase.user_id;

    IF v_purchase.admin_approved THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            'この購入は既に承認済みです'::TEXT,
            v_target_user_id,
            0::INTEGER,
            false::BOOLEAN;
        RETURN;
    END IF;

    IF v_purchase.is_auto_purchase THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            '自動購入は手動承認できません'::TEXT,
            v_target_user_id,
            0::INTEGER,
            false::BOOLEAN;
        RETURN;
    END IF;

    SELECT EXISTS(SELECT 1 FROM users u WHERE u.user_id = v_target_user_id)
    INTO v_user_exists;

    IF NOT v_user_exists THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            'ユーザーが見つかりません'::TEXT,
            v_target_user_id,
            0::INTEGER,
            false::BOOLEAN;
        RETURN;
    END IF;

    -- nft_masterテーブルにNFTレコードを作成
    SELECT COALESCE(MAX(nm.nft_sequence), 0) + 1
    INTO v_next_sequence
    FROM nft_master nm
    WHERE nm.user_id = v_target_user_id;

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
            v_target_user_id,
            v_next_sequence + i - 1,
            'manual',
            1000.00,
            NOW()::DATE,
            NOW(),
            NOW()
        );
        v_nft_created := v_nft_created + 1;
    END LOOP;

    UPDATE purchases
    SET
        admin_approved = true,
        admin_approved_at = NOW(),
        admin_approved_by = p_admin_email,
        admin_notes = COALESCE(p_admin_notes, '承認済み'),
        payment_status = 'completed'
    WHERE id::TEXT = p_purchase_id;

    UPDATE users u
    SET
        total_purchases = u.total_purchases + v_purchase.amount_usd,
        updated_at = NOW()
    WHERE u.user_id = v_target_user_id;

    -- ★★★ affiliate_cycleを条件分岐で処理 ★★★
    SELECT manual_nft_count, total_nft_count
    INTO v_existing_manual_count, v_existing_total_count
    FROM affiliate_cycle
    WHERE affiliate_cycle.user_id = v_target_user_id;

    IF FOUND THEN
        -- 既存レコードがある場合は更新
        UPDATE affiliate_cycle
        SET
            manual_nft_count = manual_nft_count + v_purchase.nft_quantity,
            total_nft_count = total_nft_count + v_purchase.nft_quantity,
            last_updated = NOW()
        WHERE affiliate_cycle.user_id = v_target_user_id;
    ELSE
        -- 新規レコードを挿入
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
            v_target_user_id,
            v_purchase.nft_quantity,
            0,
            v_purchase.nft_quantity,
            0,
            0,
            'USDT',
            1,
            NOW(),
            NOW()
        );
    END IF;

    RETURN QUERY SELECT
        'SUCCESS'::TEXT,
        FORMAT('購入を承認しました（NFT %s枚をnft_masterに作成）', v_nft_created)::TEXT,
        v_target_user_id,
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

GRANT EXECUTE ON FUNCTION approve_user_nft(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION approve_user_nft(TEXT, TEXT, TEXT) TO anon;

SELECT '✅ approve_user_nft関数 - ON CONFLICT句を削除して条件分岐に変更' as status;
