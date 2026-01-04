-- ========================================
-- 1/1のnft_daily_profitにマージンを適用
-- ========================================
-- 現在: $2.404（マージン適用前）
-- 正しい値: $2.404 × 0.7 × 0.6 = $1.010

-- 確認
SELECT '=== 修正前 ===' as section;
SELECT AVG(daily_profit) as avg_profit, COUNT(*) as records
FROM nft_daily_profit
WHERE date = '2026-01-01';

-- 修正
UPDATE nft_daily_profit
SET daily_profit = daily_profit * 0.7 * 0.6
WHERE date = '2026-01-01';

-- 確認
SELECT '=== 修正後 ===' as section;
SELECT AVG(daily_profit) as avg_profit, SUM(daily_profit) as total, COUNT(*) as records
FROM nft_daily_profit
WHERE date = '2026-01-01';

-- 0D4493確認
SELECT '=== 0D4493確認 ===' as section;
SELECT date, daily_profit
FROM nft_daily_profit
WHERE user_id = '0D4493' AND date IN ('2026-01-01', '2026-01-02')
ORDER BY date;
