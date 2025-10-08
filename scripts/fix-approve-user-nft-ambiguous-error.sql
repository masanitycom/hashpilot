-- approve_user_nft関数の「column reference "user_id" is ambiguous」エラーを修正
-- 緊急修正: 2025年10月8日

-- ============================================
-- STEP 1: 既存関数を完全に削除
-- ============================================

DROP FUNCTION IF EXISTS approve_user_nft(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS approve_user_nft(TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS approve_user_nft(TEXT, TEXT);

-- ============================================
-- STEP 2: approve_user_nft関数を再作成（テーブルエイリアス明示）
-- ============================================

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

    -- 購入レコードを取得（テーブルエイリアスp使用）
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

    -- ユーザーが存在するか確認（テーブルエイリアスu使用）
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

    -- ★★★ 重要: nft_masterテーブルにNFTレコードを作成 ★★★

    -- 次のNFTシーケンス番号を取得（テーブルエイリアスnm使用）
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

    -- purchasesテーブルを更新（テーブルエイリアスp使用）
    UPDATE purchases p
    SET
        admin_approved = true,
        admin_approved_at = NOW(),
        admin_approved_by = p_admin_email,
        admin_notes = COALESCE(p_admin_notes, '承認済み'),
        payment_status = 'completed'
    WHERE p.id = v_purchase_id;

    -- usersテーブルを更新（テーブルエイリアスu使用）
    UPDATE users u
    SET
        total_purchases = u.total_purchases + v_amount_usd,
        updated_at = NOW()
    WHERE u.user_id = v_user_id;

    -- affiliate_cycleテーブルを更新（NFTカウント）
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
        manual_nft_count = affiliate_cycle.manual_nft_count + v_nft_quantity,
        total_nft_count = affiliate_cycle.total_nft_count + v_nft_quantity,
        last_updated = NOW();

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
$$;

-- ============================================
-- STEP 3: 権限付与
-- ============================================

GRANT EXECUTE ON FUNCTION approve_user_nft(TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION approve_user_nft(TEXT, TEXT, TEXT) TO anon;

-- ============================================
-- 完了メッセージ
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE '✅ approve_user_nft関数のambiguousエラーを修正';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '修正内容:';
    RAISE NOTICE '  - 全てのSELECT/UPDATEでテーブルエイリアスを明示';
    RAISE NOTICE '  - RECORDではなく個別の変数に値を格納';
    RAISE NOTICE '  - user_idの曖昧さを完全に解消';
    RAISE NOTICE '=========================================';
END $$;
