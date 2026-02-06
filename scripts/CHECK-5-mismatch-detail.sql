-- ========================================
-- pending出金不一致5名の詳細調査
-- ========================================

-- 1. 不一致の5名を特定
SELECT '=== 1. 不一致5名の特定 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as available_usdt,
  ROUND(mw.personal_amount::numeric, 2) as pending_personal,
  ROUND((ac.available_usdt - mw.personal_amount)::numeric, 2) as diff,
  mw.withdrawal_month,
  mw.status
FROM affiliate_cycle ac
JOIN monthly_withdrawals mw ON ac.user_id = mw.user_id
WHERE mw.status = 'pending'
  AND ABS(ac.available_usdt - mw.personal_amount) >= 0.01
ORDER BY ABS(ac.available_usdt - mw.personal_amount) DESC;

-- 2. これらのユーザーに複数のpending出金がないか
SELECT '=== 2. pending出金の重複確認 ===' as section;
SELECT
  user_id,
  COUNT(*) as pending_count,
  array_agg(withdrawal_month ORDER BY withdrawal_month) as months
FROM monthly_withdrawals
WHERE status = 'pending'
GROUP BY user_id
HAVING COUNT(*) > 1;

-- 3. 不一致ユーザーの日利データ
SELECT '=== 3. 不一致ユーザーの月別日利 ===' as section;
WITH mismatch_users AS (
  SELECT ac.user_id
  FROM affiliate_cycle ac
  JOIN monthly_withdrawals mw ON ac.user_id = mw.user_id
  WHERE mw.status = 'pending'
    AND ABS(ac.available_usdt - mw.personal_amount) >= 0.01
)
SELECT
  ndp.user_id,
  TO_CHAR(ndp.date, 'YYYY-MM') as month,
  ROUND(SUM(ndp.daily_profit)::numeric, 2) as monthly_profit
FROM nft_daily_profit ndp
WHERE ndp.user_id IN (SELECT user_id FROM mismatch_users)
GROUP BY ndp.user_id, TO_CHAR(ndp.date, 'YYYY-MM')
ORDER BY ndp.user_id, month;

-- 4. 不一致ユーザーの全出金履歴
SELECT '=== 4. 不一致ユーザーの出金履歴 ===' as section;
WITH mismatch_users AS (
  SELECT ac.user_id
  FROM affiliate_cycle ac
  JOIN monthly_withdrawals mw ON ac.user_id = mw.user_id
  WHERE mw.status = 'pending'
    AND ABS(ac.available_usdt - mw.personal_amount) >= 0.01
)
SELECT
  mw.user_id,
  mw.withdrawal_month,
  mw.status,
  ROUND(COALESCE(mw.personal_amount, 0)::numeric, 2) as personal,
  ROUND(COALESCE(mw.referral_amount, 0)::numeric, 2) as referral,
  ROUND(mw.total_amount::numeric, 2) as total
FROM monthly_withdrawals mw
WHERE mw.user_id IN (SELECT user_id FROM mismatch_users)
ORDER BY mw.user_id, mw.withdrawal_month;
