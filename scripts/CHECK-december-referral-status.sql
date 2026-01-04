-- ========================================
-- 12月出金の紹介報酬ステータス確認
-- ========================================

-- 1. 12月出金で紹介報酬があるユーザー
SELECT '=== 11月紹介報酬がある12月出金ユーザー ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  COALESCE(nov.nov_referral, 0) as nov_referral,
  mw.referral_amount as dec_withdrawal_referral,
  mw.total_amount,
  mw.status
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as nov_referral
  FROM monthly_referral_profit
  WHERE year_month = '2025-11'
  GROUP BY user_id
) nov ON mw.user_id = nov.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND COALESCE(nov.nov_referral, 0) > 0
ORDER BY nov.nov_referral DESC
LIMIT 20;

-- 2. 未払いがあるかチェック
SELECT '=== 11月紹介報酬 vs 12月出金referral_amount ===' as section;
SELECT
  COUNT(*) as total_users,
  SUM(CASE WHEN COALESCE(nov.nov_referral, 0) > COALESCE(mw.referral_amount, 0) THEN 1 ELSE 0 END) as underpaid_count,
  SUM(GREATEST(0, COALESCE(nov.nov_referral, 0) - COALESCE(mw.referral_amount, 0))) as total_underpaid
FROM monthly_withdrawals mw
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as nov_referral
  FROM monthly_referral_profit
  WHERE year_month = '2025-11'
  GROUP BY user_id
) nov ON mw.user_id = nov.user_id
WHERE mw.withdrawal_month = '2025-12-01';

-- 3. referral_amountの状況
SELECT '=== referral_amountの状況 ===' as section;
SELECT
  COUNT(*) as total,
  SUM(CASE WHEN referral_amount > 0 THEN 1 ELSE 0 END) as has_referral,
  SUM(CASE WHEN referral_amount = 0 OR referral_amount IS NULL THEN 1 ELSE 0 END) as no_referral
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01';
