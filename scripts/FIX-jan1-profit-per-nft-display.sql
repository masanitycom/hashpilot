-- ========================================
-- 1/1のprofit_per_nftを修正
-- ========================================

-- 修正前確認
SELECT '=== 修正前 ===' as section;
SELECT date, total_profit_amount, total_nft_count, profit_per_nft
FROM daily_yield_log_v2
WHERE date = '2026-01-01';

-- 修正: profit_per_nft = 2500 / 1040 = 2.4038...
UPDATE daily_yield_log_v2
SET profit_per_nft = total_profit_amount / total_nft_count
WHERE date = '2026-01-01';

-- 修正後確認
SELECT '=== 修正後 ===' as section;
SELECT date, total_profit_amount, total_nft_count, profit_per_nft
FROM daily_yield_log_v2
WHERE date = '2026-01-01';
