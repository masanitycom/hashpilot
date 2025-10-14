-- ========================================
-- 7E0A1Eのaffiliate_cycleを実際のNFT数に修正
-- ========================================

-- 1. 現在の状態確認
SELECT
    '修正前の状態' as section,
    ac.user_id,
    ac.manual_nft_count as ac_manual,
    ac.auto_nft_count as ac_auto,
    ac.total_nft_count as ac_total,
    COUNT(nm.id) FILTER (WHERE nm.nft_type = 'manual' AND nm.buyback_date IS NULL) as actual_manual,
    COUNT(nm.id) FILTER (WHERE nm.nft_type = 'auto' AND nm.buyback_date IS NULL) as actual_auto,
    COUNT(nm.id) FILTER (WHERE nm.buyback_date IS NULL) as actual_total
FROM affiliate_cycle ac
LEFT JOIN nft_master nm ON ac.user_id = nm.user_id
WHERE ac.user_id = '7E0A1E'
GROUP BY ac.user_id, ac.manual_nft_count, ac.auto_nft_count, ac.total_nft_count;

-- 2. affiliate_cycleを実際のNFT数に修正
UPDATE affiliate_cycle
SET
    manual_nft_count = (
        SELECT COUNT(*)
        FROM nft_master
        WHERE user_id = '7E0A1E'
          AND nft_type = 'manual'
          AND buyback_date IS NULL
    ),
    auto_nft_count = (
        SELECT COUNT(*)
        FROM nft_master
        WHERE user_id = '7E0A1E'
          AND nft_type = 'auto'
          AND buyback_date IS NULL
    ),
    total_nft_count = (
        SELECT COUNT(*)
        FROM nft_master
        WHERE user_id = '7E0A1E'
          AND buyback_date IS NULL
    ),
    last_updated = NOW()
WHERE user_id = '7E0A1E';

-- 3. 修正後の確認
SELECT
    '修正後の状態' as section,
    ac.user_id,
    ac.manual_nft_count,
    ac.auto_nft_count,
    ac.total_nft_count,
    ac.cum_usdt,
    ac.available_usdt,
    ac.phase
FROM affiliate_cycle ac
WHERE ac.user_id = '7E0A1E';

-- 4. NFTマスターの確認
SELECT
    'NFTマスター' as section,
    nft_type,
    COUNT(*) FILTER (WHERE buyback_date IS NULL) as active_count,
    COUNT(*) FILTER (WHERE buyback_date IS NOT NULL) as buyback_count
FROM nft_master
WHERE user_id = '7E0A1E'
GROUP BY nft_type;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE '✅ 7E0A1Eのaffiliate_cycleを修正しました';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '修正内容:';
    RAISE NOTICE '  - manual_nft_count: 600 → 実際の保有数';
    RAISE NOTICE '  - auto_nft_count: 1 → 実際の保有数';
    RAISE NOTICE '  - total_nft_count: 601 → 実際の保有数';
    RAISE NOTICE '';
    RAISE NOTICE '次回から日利が正しく計算されます';
    RAISE NOTICE '=========================================';
END $$;
