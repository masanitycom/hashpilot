-- NFTマスターテーブルとaffiliate_cycleテーブルの不整合を診断
-- 問題: affiliate_cycleには600枚と記録されているが、nft_masterには0枚

-- ============================================
-- STEP 1: 特定ユーザーの状況確認
-- ============================================

-- ユーザーIDを指定（テストユーザーの場合は '7E0A1E'）
DO $$
DECLARE
    v_user_id TEXT := '7E0A1E';  -- ここにユーザーIDを入れる
    v_cycle_manual INTEGER;
    v_cycle_auto INTEGER;
    v_cycle_total INTEGER;
    v_master_manual INTEGER;
    v_master_auto INTEGER;
    v_master_total INTEGER;
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE 'NFTデータの整合性チェック: %', v_user_id;
    RAISE NOTICE '=========================================';

    -- affiliate_cycleの情報
    SELECT manual_nft_count, auto_nft_count, total_nft_count
    INTO v_cycle_manual, v_cycle_auto, v_cycle_total
    FROM affiliate_cycle
    WHERE user_id = v_user_id;

    RAISE NOTICE '';
    RAISE NOTICE '【affiliate_cycleテーブル】';
    RAISE NOTICE '  手動NFT: % 枚', v_cycle_manual;
    RAISE NOTICE '  自動NFT: % 枚', v_cycle_auto;
    RAISE NOTICE '  合計NFT: % 枚', v_cycle_total;

    -- nft_masterの情報
    SELECT
        COUNT(*) FILTER (WHERE nft_type = 'manual' AND buyback_date IS NULL),
        COUNT(*) FILTER (WHERE nft_type = 'auto' AND buyback_date IS NULL),
        COUNT(*) FILTER (WHERE buyback_date IS NULL)
    INTO v_master_manual, v_master_auto, v_master_total
    FROM nft_master
    WHERE user_id = v_user_id;

    RAISE NOTICE '';
    RAISE NOTICE '【nft_masterテーブル】';
    RAISE NOTICE '  手動NFT: % 枚', v_master_manual;
    RAISE NOTICE '  自動NFT: % 枚', v_master_auto;
    RAISE NOTICE '  合計NFT: % 枚', v_master_total;

    RAISE NOTICE '';
    RAISE NOTICE '【不整合チェック】';
    IF v_cycle_manual != v_master_manual THEN
        RAISE NOTICE '  ⚠️  手動NFT数が一致しません（差: %）', v_cycle_manual - v_master_manual;
    END IF;
    IF v_cycle_auto != v_master_auto THEN
        RAISE NOTICE '  ⚠️  自動NFT数が一致しません（差: %）', v_cycle_auto - v_master_auto;
    END IF;
    IF v_cycle_total != v_master_total THEN
        RAISE NOTICE '  ⚠️  合計NFT数が一致しません（差: %）', v_cycle_total - v_master_total;
    END IF;

    IF v_cycle_total = v_master_total THEN
        RAISE NOTICE '  ✅ NFT数は一致しています';
    END IF;

    RAISE NOTICE '=========================================';
END $$;

-- ============================================
-- STEP 2: 全ユーザーの不整合を検出
-- ============================================

SELECT '=== 全ユーザーの不整合検出 ===' as section;

SELECT
    ac.user_id,
    ac.manual_nft_count as cycle_manual,
    ac.auto_nft_count as cycle_auto,
    ac.total_nft_count as cycle_total,
    COALESCE(nm.manual_count, 0) as master_manual,
    COALESCE(nm.auto_count, 0) as master_auto,
    COALESCE(nm.total_count, 0) as master_total,
    ac.manual_nft_count - COALESCE(nm.manual_count, 0) as manual_diff,
    ac.auto_nft_count - COALESCE(nm.auto_count, 0) as auto_diff,
    ac.total_nft_count - COALESCE(nm.total_count, 0) as total_diff
FROM affiliate_cycle ac
LEFT JOIN (
    SELECT
        user_id,
        COUNT(*) FILTER (WHERE nft_type = 'manual' AND buyback_date IS NULL) as manual_count,
        COUNT(*) FILTER (WHERE nft_type = 'auto' AND buyback_date IS NULL) as auto_count,
        COUNT(*) FILTER (WHERE buyback_date IS NULL) as total_count
    FROM nft_master
    GROUP BY user_id
) nm ON ac.user_id = nm.user_id
WHERE ac.total_nft_count > 0
  AND (
    ac.manual_nft_count != COALESCE(nm.manual_count, 0)
    OR ac.auto_nft_count != COALESCE(nm.auto_count, 0)
    OR ac.total_nft_count != COALESCE(nm.total_count, 0)
  )
ORDER BY total_diff DESC;

-- ============================================
-- STEP 3: purchasesテーブルの確認
-- ============================================

SELECT '=== purchasesテーブルの確認 ===' as section;

-- ユーザーIDを指定
SELECT
    id,
    user_id,
    nft_quantity,
    amount_usd,
    payment_status,
    admin_approved,
    is_auto_purchase,
    admin_approved_at,
    created_at
FROM purchases
WHERE user_id = '7E0A1E'  -- ここにユーザーIDを入れる
ORDER BY created_at;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '診断完了';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '';
    RAISE NOTICE '次のステップ:';
    RAISE NOTICE '1. 不整合が見つかった場合:';
    RAISE NOTICE '   - purchasesテーブルに承認済み購入があるか確認';
    RAISE NOTICE '   - nft_masterテーブルにレコードを作成する必要がある';
    RAISE NOTICE '';
    RAISE NOTICE '2. 修正方法:';
    RAISE NOTICE '   - sync-nft-master-from-purchases.sql を実行';
    RAISE NOTICE '   - または手動でnft_masterレコードを作成';
    RAISE NOTICE '=========================================';
END $$;
