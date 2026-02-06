-- ========================================
-- available_usdtの現状確認
-- ========================================

-- 177B83と59C23Cの現在の状態
SELECT '=== affiliate_cycle現在の状態 ===' as section;
SELECT
  user_id,
  ROUND(available_usdt::numeric, 2) as available_usdt,
  ROUND(cum_usdt::numeric, 2) as cum_usdt,
  phase,
  ROUND(COALESCE(withdrawn_referral_usdt, 0)::numeric, 2) as withdrawn_referral,
  auto_nft_count
FROM affiliate_cycle
WHERE user_id IN ('177B83', '59C23C');

-- 月別の日利を確認
SELECT '=== 月別日利（177B83）===' as section;
SELECT
  TO_CHAR(date, 'YYYY-MM') as month,
  COUNT(*) as days,
  ROUND(SUM(daily_profit)::numeric, 2) as daily_profit_total
FROM nft_daily_profit
WHERE user_id = '177B83'
GROUP BY TO_CHAR(date, 'YYYY-MM')
ORDER BY month;

SELECT '=== 月別日利（59C23C）===' as section;
SELECT
  TO_CHAR(date, 'YYYY-MM') as month,
  COUNT(*) as days,
  ROUND(SUM(daily_profit)::numeric, 2) as daily_profit_total
FROM nft_daily_profit
WHERE user_id = '59C23C'
GROUP BY TO_CHAR(date, 'YYYY-MM')
ORDER BY month;

-- 出金履歴を確認
SELECT '=== 出金履歴（177B83）===' as section;
SELECT
  withdrawal_month,
  status,
  ROUND(COALESCE(personal_amount, 0)::numeric, 2) as personal,
  ROUND(COALESCE(referral_amount, 0)::numeric, 2) as referral,
  ROUND(total_amount::numeric, 2) as total
FROM monthly_withdrawals
WHERE user_id = '177B83'
ORDER BY withdrawal_month;

SELECT '=== 出金履歴（59C23C）===' as section;
SELECT
  withdrawal_month,
  status,
  ROUND(COALESCE(personal_amount, 0)::numeric, 2) as personal,
  ROUND(COALESCE(referral_amount, 0)::numeric, 2) as referral,
  ROUND(total_amount::numeric, 2) as total
FROM monthly_withdrawals
WHERE user_id = '59C23C'
ORDER BY withdrawal_month;

-- 今月（1月）の日利合計
SELECT '=== 1月日利（177B83, 59C23C）===' as section;
SELECT
  user_id,
  ROUND(SUM(daily_profit)::numeric, 2) as january_daily_profit
FROM nft_daily_profit
WHERE user_id IN ('177B83', '59C23C')
  AND date >= '2026-01-01'
  AND date < '2026-02-01'
GROUP BY user_id;

-- 2月の日利合計
SELECT '=== 2月日利（177B83, 59C23C）===' as section;
SELECT
  user_id,
  ROUND(SUM(daily_profit)::numeric, 2) as february_daily_profit
FROM nft_daily_profit
WHERE user_id IN ('177B83', '59C23C')
  AND date >= '2026-02-01'
GROUP BY user_id;
