-- =============================================
-- 12月の紹介報酬を全テーブルから検索
-- =============================================

-- 1. monthly_referral_profit（year_month形式）
SELECT '=== 1. monthly_referral_profit ===' as section;
SELECT
  year_month,
  COUNT(*) as records,
  SUM(profit_amount) as total_amount
FROM monthly_referral_profit
GROUP BY year_month
ORDER BY year_month;

-- 2. user_referral_profit（日次）
SELECT '=== 2. user_referral_profit 月別 ===' as section;
SELECT
  DATE_TRUNC('month', date)::date as month,
  COUNT(*) as records,
  SUM(profit_amount) as total_amount
FROM user_referral_profit
GROUP BY DATE_TRUNC('month', date)
ORDER BY month;

-- 3. user_referral_profit_monthly が存在するか
SELECT '=== 3. user_referral_profit_monthly ===' as section;
SELECT
  year,
  month,
  COUNT(*) as records,
  SUM(profit_amount) as total_amount
FROM user_referral_profit_monthly
GROUP BY year, month
ORDER BY year, month;

-- 4. affiliate_cycle のcum_usdt合計
SELECT '=== 4. affiliate_cycle cum_usdt合計 ===' as section;
SELECT
  SUM(cum_usdt) as total_cum_usdt,
  SUM(available_usdt) as total_available_usdt
FROM affiliate_cycle;

-- 5. monthly_referral_profit の12月データ詳細
SELECT '=== 5. monthly_referral_profit 2025-12 ===' as section;
SELECT *
FROM monthly_referral_profit
WHERE year_month = '2025-12'
LIMIT 10;

-- 6. 全紹介報酬テーブルのレコード数
SELECT '=== 6. 全紹介報酬テーブル レコード数 ===' as section;
SELECT 'monthly_referral_profit' as table_name, COUNT(*) as count FROM monthly_referral_profit
UNION ALL
SELECT 'user_referral_profit', COUNT(*) FROM user_referral_profit
UNION ALL
SELECT 'user_referral_profit_monthly', COUNT(*) FROM user_referral_profit_monthly;
