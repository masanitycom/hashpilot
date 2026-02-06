-- 7A9637のデータ確認

-- 1. affiliate_cycle
SELECT '=== 1. affiliate_cycle ===' as section;
SELECT
  user_id,
  phase,
  ROUND(cum_usdt::numeric, 2) as cum_usdt,
  ROUND(COALESCE(withdrawn_referral_usdt, 0)::numeric, 2) as withdrawn_referral,
  ROUND(available_usdt::numeric, 2) as available_usdt
FROM affiliate_cycle
WHERE user_id = '7A9637';

-- 2. 月別紹介報酬
SELECT '=== 2. 月別紹介報酬 ===' as section;
SELECT
  year_month,
  ROUND(SUM(profit_amount)::numeric, 2) as total
FROM monthly_referral_profit
WHERE user_id = '7A9637'
GROUP BY year_month
ORDER BY year_month;

-- 3. 1月のmonthly_withdrawals
SELECT '=== 3. 1月出金レコード ===' as section;
SELECT
  withdrawal_month,
  status,
  ROUND(personal_amount::numeric, 2) as personal,
  ROUND(referral_amount::numeric, 2) as referral,
  ROUND(total_amount::numeric, 2) as total
FROM monthly_withdrawals
WHERE user_id = '7A9637'
  AND withdrawal_month = '2026-01-01';

-- 4. 過去の出金履歴
SELECT '=== 4. 全出金履歴 ===' as section;
SELECT
  withdrawal_month,
  status,
  ROUND(personal_amount::numeric, 2) as personal,
  ROUND(COALESCE(referral_amount, 0)::numeric, 2) as referral,
  ROUND(total_amount::numeric, 2) as total
FROM monthly_withdrawals
WHERE user_id = '7A9637'
ORDER BY withdrawal_month;
