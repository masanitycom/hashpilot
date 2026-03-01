-- ========================================
-- 2月月末処理の状態確認
-- ========================================

-- 1. 2月の日利設定状況（最後まで設定されたか）
SELECT '=== 1. 2月の日利設定日 ===' as section;
SELECT date, total_nft_count, ROUND(daily_pnl::numeric, 2) as daily_pnl
FROM daily_yield_log_v2
WHERE date >= '2026-02-25'
ORDER BY date;

-- 2. 2月の紹介報酬が計算されたか
SELECT '=== 2. monthly_referral_profit (2月) ===' as section;
SELECT
  year_month,
  COUNT(*) as record_count,
  ROUND(SUM(profit_amount)::numeric, 2) as total_amount
FROM monthly_referral_profit
WHERE year_month = '2026-02'
GROUP BY year_month;

-- 3. 2月の出金申請が作成されたか
SELECT '=== 3. monthly_withdrawals (2月) ===' as section;
SELECT
  withdrawal_month,
  COUNT(*) as record_count,
  SUM(CASE WHEN status = 'on_hold' THEN 1 ELSE 0 END) as on_hold_count,
  SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_count,
  SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) as completed_count,
  ROUND(SUM(total_amount)::numeric, 2) as total_withdrawal
FROM monthly_withdrawals
WHERE withdrawal_month >= '2026-02-01'
GROUP BY withdrawal_month;

-- 4. 過去の月末処理との比較
SELECT '=== 4. 月別の紹介報酬計算履歴 ===' as section;
SELECT
  year_month,
  COUNT(*) as records,
  ROUND(SUM(profit_amount)::numeric, 2) as total
FROM monthly_referral_profit
GROUP BY year_month
ORDER BY year_month;
