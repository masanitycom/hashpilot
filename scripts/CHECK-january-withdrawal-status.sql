-- ========================================
-- 1月出金データの状態確認
-- ========================================

-- 59C23Cと177B83の状態
SELECT '=== 59C23C, 177B83の状態 ===' as section;
SELECT 
  user_id,
  total_amount,
  personal_amount,
  referral_amount,
  status,
  task_completed
FROM monthly_withdrawals
WHERE user_id IN ('59C23C', '177B83')
  AND withdrawal_month = '2026-01-01';

-- $10未満の出金レコード
SELECT '=== $10未満のレコード ===' as section;
SELECT 
  user_id,
  total_amount,
  status,
  task_completed
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01'
  AND total_amount < 10
ORDER BY total_amount;

-- タスク未完了（on_hold）のユーザー数
SELECT '=== ステータス別集計 ===' as section;
SELECT 
  status,
  COUNT(*) as 件数,
  SUM(total_amount) as 合計
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01'
GROUP BY status;
