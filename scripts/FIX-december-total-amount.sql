-- ========================================
-- 12月出金のtotal_amountを修正
-- total_amount = personal_amount + referral_amount
-- ========================================

-- 修正前確認
SELECT '=== 修正前：差額があるユーザー ===' as section;
SELECT
  user_id,
  personal_amount,
  referral_amount,
  total_amount,
  (personal_amount + COALESCE(referral_amount, 0)) as correct_total,
  (personal_amount + COALESCE(referral_amount, 0)) - total_amount as difference,
  status
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01'
  AND ABS((personal_amount + COALESCE(referral_amount, 0)) - total_amount) > 0.01
ORDER BY (personal_amount + COALESCE(referral_amount, 0)) - total_amount DESC
LIMIT 20;

-- 修正前統計
SELECT '=== 修正前統計 ===' as section;
SELECT
  COUNT(*) as total_users,
  SUM(total_amount) as current_total,
  SUM(personal_amount + COALESCE(referral_amount, 0)) as correct_total,
  SUM(personal_amount + COALESCE(referral_amount, 0)) - SUM(total_amount) as additional_payment
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01';

-- 修正実行
SELECT '=== 修正実行 ===' as section;
UPDATE monthly_withdrawals
SET total_amount = personal_amount + COALESCE(referral_amount, 0)
WHERE withdrawal_month = '2025-12-01';

-- 修正後確認
SELECT '=== 修正後統計 ===' as section;
SELECT
  COUNT(*) as total_users,
  SUM(total_amount) as new_total,
  SUM(personal_amount) as personal_total,
  SUM(referral_amount) as referral_total
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01';
