-- =============================================
-- 12月の紹介報酬がどう計算されたか確認
-- =============================================

-- =============================================
-- 1. user_referral_profit（日次）に12月のデータがあるか
-- =============================================
SELECT '=== 1. user_referral_profit（日次）12月データ ===' as section;

SELECT
  date,
  COUNT(*) as records,
  SUM(profit_amount) as total_amount
FROM user_referral_profit
WHERE date >= '2025-12-01' AND date <= '2025-12-31'
GROUP BY date
ORDER BY date;

-- 12月の日次紹介報酬合計
SELECT '=== 12月の日次紹介報酬合計 ===' as section;
SELECT
  COUNT(*) as total_records,
  SUM(profit_amount) as total_amount
FROM user_referral_profit
WHERE date >= '2025-12-01' AND date <= '2025-12-31';

-- =============================================
-- 2. monthly_referral_profit に12月のデータがあるか
-- =============================================
SELECT '=== 2. monthly_referral_profit 12月データ ===' as section;

SELECT *
FROM monthly_referral_profit
WHERE profit_month >= '2025-12-01' AND profit_month < '2026-01-01'
LIMIT 20;

-- monthly_referral_profitのカラム構造確認
SELECT '=== monthly_referral_profit のカラム構造 ===' as section;
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'monthly_referral_profit'
ORDER BY ordinal_position;

-- =============================================
-- 3. 11月との比較
-- =============================================
SELECT '=== 3. 11月の日次紹介報酬 ===' as section;

SELECT
  date,
  COUNT(*) as records,
  SUM(profit_amount) as total_amount
FROM user_referral_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-30'
GROUP BY date
ORDER BY date;

-- =============================================
-- 4. monthly_referral_profitの全データ（月別）
-- =============================================
SELECT '=== 4. monthly_referral_profit 月別集計 ===' as section;

SELECT
  DATE_TRUNC('month', profit_month) as month,
  COUNT(*) as records,
  SUM(profit_amount) as total_amount
FROM monthly_referral_profit
GROUP BY DATE_TRUNC('month', profit_month)
ORDER BY month;

-- =============================================
-- 5. 12月の出金で紹介報酬はどう処理されたか
-- =============================================
SELECT '=== 5. 12月の出金データ ===' as section;

SELECT
  user_id,
  target_month,
  personal_amount,
  referral_amount,
  total_amount,
  status
FROM monthly_withdrawals
WHERE target_month >= '2025-12-01' AND target_month < '2026-01-01'
LIMIT 20;

-- =============================================
-- 6. daily_yield_log_v2の12月データ
-- =============================================
SELECT '=== 6. daily_yield_log_v2 12月データ ===' as section;

SELECT
  date,
  total_profit_amount,
  total_nft_count,
  distribution_dividend,
  distribution_affiliate
FROM daily_yield_log_v2
WHERE date >= '2025-12-01' AND date <= '2025-12-31'
ORDER BY date;

-- =============================================
-- 7. どのRPC関数が12月に使われたか推測
-- =============================================
SELECT '=== 7. 考察 ===' as section;

SELECT
  CASE
    WHEN (SELECT COUNT(*) FROM user_referral_profit WHERE date >= '2025-12-01' AND date <= '2025-12-31') > 0
    THEN '12月は日次紹介報酬（user_referral_profit）が使われた'
    ELSE '12月は日次紹介報酬が使われていない'
  END as daily_referral_status,
  CASE
    WHEN (SELECT COUNT(*) FROM monthly_referral_profit WHERE profit_month >= '2025-12-01' AND profit_month < '2026-01-01') > 0
    THEN '12月は月次紹介報酬（monthly_referral_profit）が使われた'
    ELSE '12月は月次紹介報酬が使われていない'
  END as monthly_referral_status;
