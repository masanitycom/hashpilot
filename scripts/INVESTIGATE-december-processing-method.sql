-- ========================================
-- 12月の日利処理方法の確認
-- ========================================

-- 1. daily_yield_log_v2に12月のデータがあるか
SELECT '=== 1. daily_yield_log_v2（V2処理）===' as section;
SELECT
  date,
  total_profit_amount,
  profit_per_nft,
  distribution_dividend,
  created_at
FROM daily_yield_log_v2
WHERE date >= '2025-12-01' AND date <= '2025-12-31'
ORDER BY date
LIMIT 10;

-- 2. daily_yield_log（V1処理）に12月のデータがあるか
SELECT '=== 2. daily_yield_log（V1処理）===' as section;
SELECT
  date,
  yield_rate,
  user_rate,
  created_at
FROM daily_yield_log
WHERE date >= '2025-12-01' AND date <= '2025-12-31'
ORDER BY date
LIMIT 10;

-- 3. user_referral_profit（日次紹介報酬）に12月のデータがあるか
SELECT '=== 3. user_referral_profit（日次）===' as section;
SELECT
  COUNT(*) as record_count,
  SUM(profit_amount) as total_amount,
  MIN(date) as first_date,
  MAX(date) as last_date
FROM user_referral_profit
WHERE date >= '2025-12-01' AND date <= '2025-12-31';

-- 4. user_referral_profit_monthly（月次紹介報酬）に12月のデータがあるか
SELECT '=== 4. user_referral_profit_monthly（月次）===' as section;
SELECT
  COUNT(*) as record_count,
  SUM(profit_amount) as total_amount
FROM user_referral_profit_monthly
WHERE created_at >= '2025-12-01';

-- 5. ACACDBのuser_referral_profit（日次）
SELECT '=== 5. ACACDB: user_referral_profit（日次）===' as section;
SELECT
  date,
  referral_level,
  child_user_id,
  profit_amount
FROM user_referral_profit
WHERE user_id = 'ACACDB'
ORDER BY date
LIMIT 20;

-- 6. ACACDBのuser_referral_profit_monthly（月次）
SELECT '=== 6. ACACDB: user_referral_profit_monthly（月次）===' as section;
SELECT *
FROM user_referral_profit_monthly
WHERE user_id = 'ACACDB';

-- 7. 日次と月次の紹介報酬の比較
SELECT '=== 7. 日次 vs 月次 紹介報酬の比較 ===' as section;
SELECT
  urp.user_id,
  urp.daily_total,
  urpm.monthly_total,
  urp.daily_total - urpm.monthly_total as difference
FROM (
  SELECT user_id, SUM(profit_amount) as daily_total
  FROM user_referral_profit
  GROUP BY user_id
) urp
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as monthly_total
  FROM user_referral_profit_monthly
  GROUP BY user_id
) urpm ON urp.user_id = urpm.user_id
WHERE ABS(urp.daily_total - COALESCE(urpm.monthly_total, 0)) > 1
ORDER BY ABS(urp.daily_total - COALESCE(urpm.monthly_total, 0)) DESC
LIMIT 20;
