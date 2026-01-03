-- =============================================
-- 12月の紹介報酬確認（カラム名修正版）
-- =============================================

-- 1. monthly_referral_profitのカラム構造
SELECT '=== 1. monthly_referral_profit カラム構造 ===' as section;
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'monthly_referral_profit'
ORDER BY ordinal_position;

-- 2. monthly_referral_profitの全データサンプル
SELECT '=== 2. monthly_referral_profit サンプル ===' as section;
SELECT * FROM monthly_referral_profit LIMIT 10;

-- 3. user_referral_profitの月別集計
SELECT '=== 3. user_referral_profit 月別集計 ===' as section;
SELECT
  DATE_TRUNC('month', date) as month,
  COUNT(*) as records,
  SUM(profit_amount) as total_amount
FROM user_referral_profit
GROUP BY DATE_TRUNC('month', date)
ORDER BY month;

-- 4. 今日(1/1)だけのデータ確認
SELECT '=== 4. 2026/1/1 の日次紹介報酬 ===' as section;
SELECT
  user_id,
  referral_level,
  child_user_id,
  profit_amount
FROM user_referral_profit
WHERE date = '2026-01-01'
LIMIT 20;

-- 5. process_daily_yield_v2の定義を確認
SELECT '=== 5. process_daily_yield_v2 関数の存在確認 ===' as section;
SELECT
  routine_name,
  routine_type,
  created
FROM information_schema.routines
WHERE routine_name = 'process_daily_yield_v2';
