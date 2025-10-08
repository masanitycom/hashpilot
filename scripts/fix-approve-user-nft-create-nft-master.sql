-- 購入承認時にnft_masterレコードを自動作成する機能を追加
-- 根本原因: approve_user_nft関数がnft_masterテーブルにレコードを作成していなかった
-- 作成日: 2025年10月8日

-- ============================================
-- STEP 1: 既存関数を削除
-- ============================================

DROP FUNCTION IF EXISTS approve_user_nft(UUID, TEXT, TEXT);
DROP FUNCTION IF EXISTS approve_user_nft(TEXT, TEXT, TEXT);

-- ============================================
-- STEP 2: approve_user_nft関数を再作成
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

    -- ★★★ 重要: nft_masterテーブルにNFTレコードを作成 ★★★

    -- 次のNFTシーケンス番号を取得
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
            'manual',  -- 手動購入は全てmanual
            1100.00,
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
        manual_nft_count = affiliate_cycle.manual_nft_count + v_purchase.nft_quantity,
        total_nft_count = affiliate_cycle.total_nft_count + v_purchase.nft_quantity,
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

-- ============================================
-- STEP 3: 権限付与
-- ============================================

GRANT EXECUTE ON FUNCTION approve_user_nft(TEXT, TEXT, TEXT) TO authenticated;

-- ============================================
-- STEP 4: テスト用クエリ
-- ============================================

-- 承認前の状態確認
SELECT
    '=== 承認前の状態確認 ===' as section,
    p.id as purchase_id,
    p.user_id,
    p.nft_quantity,
    p.admin_approved,
    COALESCE(nm.nft_count, 0) as current_nft_master_count,
    COALESCE(ac.manual_nft_count, 0) as current_affiliate_cycle_count
FROM purchases p
LEFT JOIN (
    SELECT user_id, COUNT(*) as nft_count
    FROM nft_master
    WHERE nft_type = 'manual' AND buyback_date IS NULL
    GROUP BY user_id
) nm ON p.user_id = nm.user_id
LEFT JOIN affiliate_cycle ac ON p.user_id = ac.user_id
WHERE p.admin_approved = false
  AND p.is_auto_purchase = false
ORDER BY p.created_at DESC
LIMIT 5;

-- ============================================
-- 完了メッセージ
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE '✅ approve_user_nft関数を修正しました';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '修正内容:';
    RAISE NOTICE '  1. 購入承認時に自動的にnft_masterレコードを作成';
    RAISE NOTICE '  2. nft_sequenceは既存レコードの続き番号から開始';
    RAISE NOTICE '  3. nft_type = ''manual''（手動購入）';
    RAISE NOTICE '  4. nft_value = 1100.00';
    RAISE NOTICE '  5. acquired_date = 承認日';
    RAISE NOTICE '';
    RAISE NOTICE '根本原因:';
    RAISE NOTICE '  - 以前の関数はaffiliate_cycleのカウントだけ更新';
    RAISE NOTICE '  - nft_masterテーブルにレコードを作成していなかった';
    RAISE NOTICE '';
    RAISE NOTICE '影響:';
    RAISE NOTICE '  - 今後の購入承認時に自動的にnft_masterレコードが作成される';
    RAISE NOTICE '  - データ不整合が発生しなくなる';
    RAISE NOTICE '=========================================';
END $$;
