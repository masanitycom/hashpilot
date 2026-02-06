-- ========================================
-- 177B83のタスク表示修正
-- ========================================

-- 177B83: $11.89 >= $10 なのでタスク表示対象
-- statusをon_holdに戻してタスクを表示させる
UPDATE monthly_withdrawals
SET 
  status = 'on_hold',
  task_completed = false,
  updated_at = NOW()
WHERE user_id = '177B83'
  AND withdrawal_month = '2026-01-01';

-- 59C23C: $5.48 < $10 なので出金対象外、レコード削除
DELETE FROM monthly_withdrawals
WHERE user_id = '59C23C'
  AND withdrawal_month = '2026-01-01';

-- 確認
SELECT '=== 修正後 ===' as section;
SELECT 
  user_id, total_amount, status, task_completed
FROM monthly_withdrawals
WHERE user_id IN ('59C23C', '177B83')
  AND withdrawal_month = '2026-01-01';

-- ステータス別集計
SELECT '=== ステータス別集計 ===' as section;
SELECT 
  status,
  COUNT(*) as 件数,
  SUM(total_amount) as 合計
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01'
GROUP BY status;
