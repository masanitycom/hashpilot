-- ========================================
-- 1月出金データのステータス一括修正
-- ========================================
-- 問題: 全員status='pending'でタスクが表示されない
-- 修正: 
--   - タスク未完了者 → status='on_hold'
--   - タスク完了者 → status='pending'（そのまま）
--   - $10未満 → レコード削除
-- ========================================

-- STEP 1: 修正前の状態
SELECT '=== STEP 1: 修正前 ===' as section;
SELECT 
  status,
  task_completed,
  COUNT(*) as 件数,
  SUM(total_amount) as 合計
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01'
GROUP BY status, task_completed
ORDER BY status, task_completed;

-- STEP 2: $10未満のレコードを削除
SELECT '=== STEP 2: $10未満を削除 ===' as section;
DELETE FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01'
  AND total_amount < 10;

-- STEP 3: タスク未完了者のstatusをon_holdに戻す
SELECT '=== STEP 3: タスク未完了者をon_holdに ===' as section;
UPDATE monthly_withdrawals
SET 
  status = 'on_hold',
  updated_at = NOW()
WHERE withdrawal_month = '2026-01-01'
  AND task_completed = false
  AND status = 'pending';

-- STEP 4: 修正後の状態
SELECT '=== STEP 4: 修正後 ===' as section;
SELECT 
  status,
  task_completed,
  COUNT(*) as 件数,
  SUM(total_amount) as 合計
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01'
GROUP BY status, task_completed
ORDER BY status, task_completed;

-- STEP 5: 最終サマリー
SELECT '=== STEP 5: 最終サマリー ===' as section;
SELECT 
  COUNT(*) as 出金対象者数,
  SUM(total_amount) as 出金合計,
  SUM(CASE WHEN status = 'on_hold' THEN 1 ELSE 0 END) as タスク未完了,
  SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as タスク完了_送金待ち
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01';
