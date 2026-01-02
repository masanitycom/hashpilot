-- ========================================
-- ACBFBA 11月の日利が存在するか確認
-- ========================================

-- 1. 11月の日利詳細
SELECT '=== 1. 11月の日利 ===' as section;
SELECT
  date,
  daily_profit
FROM nft_daily_profit
WHERE user_id = 'ACBFBA'
  AND date >= '2025-11-01' AND date < '2025-12-01'
ORDER BY date;

-- 2. 11月の日利合計
SELECT '=== 2. 11月日利合計 ===' as section;
SELECT
  SUM(daily_profit) as nov_total
FROM nft_daily_profit
WHERE user_id = 'ACBFBA'
  AND date >= '2025-11-01' AND date < '2025-12-01';

-- 3. 12月の日利合計
SELECT '=== 3. 12月日利合計 ===' as section;
SELECT
  SUM(daily_profit) as dec_total
FROM nft_daily_profit
WHERE user_id = 'ACBFBA'
  AND date >= '2025-12-01' AND date < '2026-01-01';

-- 4. 全期間の日利合計
SELECT '=== 4. 全期間日利合計 ===' as section;
SELECT
  SUM(daily_profit) as all_total
FROM nft_daily_profit
WHERE user_id = 'ACBFBA';
