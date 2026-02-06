-- ========================================
-- マイナスユーザーの運用開始日確認
-- ========================================

-- 1. マイナスユーザーの運用開始日分布
SELECT '=== 1. マイナスユーザーの運用開始日 ===' as section;
SELECT
  u.operation_start_date,
  COUNT(*) as user_count,
  ROUND(SUM(ac.available_usdt)::numeric, 2) as total_available
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE ac.available_usdt < 0
GROUP BY u.operation_start_date
ORDER BY u.operation_start_date;

-- 2. マイナスユーザーの詳細（上位20名）
SELECT '=== 2. マイナスユーザー詳細 ===' as section;
SELECT
  ac.user_id,
  u.operation_start_date,
  ROUND(ac.available_usdt::numeric, 2) as available_usdt,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = ac.user_id AND nm.buyback_date IS NULL) as nft_count
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE ac.available_usdt < 0
ORDER BY ac.available_usdt ASC
LIMIT 20;

-- 3. 1/15運用開始ユーザーの日利データ確認
SELECT '=== 3. 1/15運用開始ユーザーの月別日利 ===' as section;
SELECT
  ndp.user_id,
  TO_CHAR(ndp.date, 'YYYY-MM') as month,
  ROUND(SUM(ndp.daily_profit)::numeric, 2) as monthly_profit,
  COUNT(*) as days
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date = '2026-01-15'
GROUP BY ndp.user_id, TO_CHAR(ndp.date, 'YYYY-MM')
ORDER BY ndp.user_id, month
LIMIT 30;

-- 4. 1/15以降の日利率の傾向
SELECT '=== 4. 1/15以降の日別利率 ===' as section;
SELECT
  date,
  ROUND(SUM(daily_profit)::numeric, 2) as total_profit,
  COUNT(DISTINCT user_id) as user_count,
  ROUND((SUM(daily_profit) / COUNT(DISTINCT user_id))::numeric, 2) as avg_per_user
FROM nft_daily_profit
WHERE date >= '2026-01-15'
GROUP BY date
ORDER BY date;

-- 5. 元データ（nft_daily_profit）は壊れていないか確認
SELECT '=== 5. nft_daily_profit全体統計 ===' as section;
SELECT
  TO_CHAR(date, 'YYYY-MM') as month,
  COUNT(*) as records,
  COUNT(DISTINCT user_id) as users,
  ROUND(SUM(daily_profit)::numeric, 2) as total_profit
FROM nft_daily_profit
GROUP BY TO_CHAR(date, 'YYYY-MM')
ORDER BY month;
