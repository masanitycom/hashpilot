-- ========================================
-- 1/2のNFT数を確認
-- ========================================

-- 1/2時点で運用中のNFT数
SELECT '=== 1/2時点で運用中のNFT数 ===' as section;
SELECT COUNT(*) as expected_nft_count
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-02'
  AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

-- daily_yield_log_v2の1/2
SELECT '=== daily_yield_log_v2 1/2 ===' as section;
SELECT date, total_profit_amount, total_nft_count, profit_per_nft
FROM daily_yield_log_v2
WHERE date = '2026-01-02';

-- nft_daily_profitの1/2レコード数
SELECT '=== nft_daily_profit 1/2レコード数 ===' as section;
SELECT COUNT(*) as records FROM nft_daily_profit WHERE date = '2026-01-02';
