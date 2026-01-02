-- ========================================
-- 繰越問題の調査
-- ========================================

-- 1. 11月分が完了済みのユーザーで、12月に繰越があるケース
SELECT '=== 1. 11月完了済みで12月に繰越があるユーザー ===' as section;
SELECT
  mw12.user_id,
  mw11.total_amount as nov_total,
  mw11.status as nov_status,
  mw12.total_amount as dec_total,
  mw12.personal_amount as dec_personal,
  mw12.referral_amount as dec_referral,
  mw12.total_amount - (mw12.personal_amount + mw12.referral_amount) as carryover,
  mw12.status as dec_status
FROM monthly_withdrawals mw12
LEFT JOIN monthly_withdrawals mw11
  ON mw12.user_id = mw11.user_id
  AND mw11.withdrawal_month = '2025-11-01'
WHERE mw12.withdrawal_month = '2025-12-01'
  AND mw12.total_amount > (mw12.personal_amount + mw12.referral_amount) + 0.01
ORDER BY mw12.total_amount - (mw12.personal_amount + mw12.referral_amount) DESC
LIMIT 20;

-- 2. 0D4493の11月出金完了後にavailable_usdtが減算されたか確認
SELECT '=== 2. 0D4493の状態 ===' as section;
SELECT
  ac.user_id,
  ac.available_usdt as current_available,
  mw11.total_amount as nov_withdrawal,
  mw11.status as nov_status,
  mw12.total_amount as dec_withdrawal,
  mw12.status as dec_status
FROM affiliate_cycle ac
LEFT JOIN monthly_withdrawals mw11 ON ac.user_id = mw11.user_id AND mw11.withdrawal_month = '2025-11-01'
LEFT JOIN monthly_withdrawals mw12 ON ac.user_id = mw12.user_id AND mw12.withdrawal_month = '2025-12-01'
WHERE ac.user_id = '0D4493';

-- 3. complete_withdrawals_batch関数がavailable_usdtを減算しているか確認
-- 11月分completedのユーザーのavailable_usdt状態
SELECT '=== 3. 11月完了済みユーザーのavailable_usdt ===' as section;
SELECT
  mw.user_id,
  mw.total_amount as nov_withdrawal,
  ac.available_usdt as current_available,
  mw.status
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-11-01'
  AND mw.status = 'completed'
ORDER BY mw.total_amount DESC
LIMIT 10;

-- 4. 11月未完了（pending/on_hold）のユーザー
SELECT '=== 4. 11月未完了のユーザー ===' as section;
SELECT
  mw.user_id,
  mw.total_amount,
  mw.status,
  mw.task_completed
FROM monthly_withdrawals mw
WHERE mw.withdrawal_month = '2025-11-01'
  AND mw.status IN ('pending', 'on_hold')
ORDER BY mw.total_amount DESC;
