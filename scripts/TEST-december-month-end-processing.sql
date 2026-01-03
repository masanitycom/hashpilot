-- =============================================
-- 12月月末処理テスト用確認スクリプト
-- =============================================
-- 目的: 12/31の日利設定後の月末処理が正しく動作するかテスト
-- =============================================

-- =============================================
-- STEP 1: 現在のデータ状況確認
-- =============================================

-- 1-1. 12月の日利データ確認
SELECT '=== 1-1. 12月の日利データ（daily_yield_log_v2） ===' as section;
SELECT
  date,
  total_profit_amount,
  total_nft_count,
  profit_per_nft,
  distribution_dividend,
  distribution_affiliate
FROM daily_yield_log_v2
WHERE date >= '2025-12-01' AND date <= '2025-12-31'
ORDER BY date;

-- 1-2. 12月の日利件数と合計
SELECT '=== 1-2. 12月の日利統計 ===' as section;
SELECT
  COUNT(*) as total_days,
  SUM(total_profit_amount) as total_profit,
  SUM(distribution_dividend) as total_dividend
FROM daily_yield_log_v2
WHERE date >= '2025-12-01' AND date <= '2025-12-31';

-- =============================================
-- STEP 2: 紹介報酬データ確認
-- =============================================

-- 2-1. monthly_referral_profit（月次紹介報酬）確認
SELECT '=== 2-1. monthly_referral_profit ===' as section;
SELECT
  year,
  month,
  COUNT(*) as records,
  SUM(profit_amount) as total_amount
FROM monthly_referral_profit
GROUP BY year, month
ORDER BY year DESC, month DESC;

-- 2-2. user_referral_profit（日次紹介報酬 - 廃止済み）確認
SELECT '=== 2-2. user_referral_profit（日次・廃止済み） ===' as section;
SELECT
  DATE_TRUNC('month', date) as month,
  COUNT(*) as records,
  SUM(profit_amount) as total_amount
FROM user_referral_profit
GROUP BY DATE_TRUNC('month', date)
ORDER BY month DESC;

-- =============================================
-- STEP 3: 月末出金データ確認
-- =============================================

-- 3-1. monthly_withdrawals のステータス別件数
SELECT '=== 3-1. monthly_withdrawals ステータス別 ===' as section;
SELECT
  withdrawal_month,
  status,
  COUNT(*) as count,
  SUM(total_amount) as total_amount
FROM monthly_withdrawals
GROUP BY withdrawal_month, status
ORDER BY withdrawal_month DESC, status;

-- 3-2. 12月分の月末出金詳細
SELECT '=== 3-2. 12月分の月末出金詳細 ===' as section;
SELECT
  user_id,
  withdrawal_month,
  personal_amount,
  referral_amount,
  total_amount,
  status,
  task_completed
FROM monthly_withdrawals
WHERE withdrawal_month >= '2025-12-01' AND withdrawal_month < '2026-01-01'
ORDER BY total_amount DESC
LIMIT 20;

-- =============================================
-- STEP 4: タスク確認
-- =============================================

-- 4-1. monthly_reward_tasks 確認
SELECT '=== 4-1. monthly_reward_tasks 確認 ===' as section;
SELECT
  year,
  month,
  COUNT(*) as total_users,
  SUM(CASE WHEN is_completed THEN 1 ELSE 0 END) as completed_count,
  SUM(CASE WHEN NOT is_completed THEN 1 ELSE 0 END) as pending_count
FROM monthly_reward_tasks
GROUP BY year, month
ORDER BY year DESC, month DESC;

-- =============================================
-- STEP 5: affiliate_cycle 確認
-- =============================================

-- 5-1. affiliate_cycle 合計
SELECT '=== 5-1. affiliate_cycle 合計 ===' as section;
SELECT
  SUM(cum_usdt) as total_cum_usdt,
  SUM(available_usdt) as total_available_usdt,
  COUNT(*) as user_count
FROM affiliate_cycle;

-- 5-2. available_usdt >= $10 のユーザー数（出金対象候補）
SELECT '=== 5-2. 出金対象候補（available_usdt >= $10） ===' as section;
SELECT
  COUNT(*) as eligible_users,
  SUM(available_usdt) as total_eligible_amount
FROM affiliate_cycle
WHERE available_usdt >= 10;

-- =============================================
-- まとめ
-- =============================================
SELECT '=== まとめ ===' as section;
SELECT
  (SELECT COUNT(*) FROM daily_yield_log_v2 WHERE date >= '2025-12-01' AND date <= '2025-12-31') as december_yield_days,
  (SELECT SUM(profit_amount) FROM monthly_referral_profit WHERE year = 2025 AND month = 12) as december_referral_total,
  (SELECT COUNT(*) FROM monthly_withdrawals WHERE withdrawal_month >= '2025-12-01' AND withdrawal_month < '2026-01-01') as december_withdrawal_count,
  (SELECT COUNT(*) FROM monthly_reward_tasks WHERE year = 2025 AND month = 12) as december_task_count;
