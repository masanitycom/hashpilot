-- ========================================
-- 1月出金データの確認
-- ========================================

-- 1. 出金レコード件数と金額
SELECT '=== 1月出金サマリー ===' as section;
SELECT 
  COUNT(*) as 件数,
  SUM(total_amount) as 出金合計,
  SUM(personal_amount) as 個人利益合計,
  SUM(referral_amount) as 紹介報酬合計
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01';

-- 2. ステータス別集計
SELECT '=== ステータス別 ===' as section;
SELECT 
  status,
  COUNT(*) as 件数,
  SUM(total_amount) as 金額
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01'
GROUP BY status
ORDER BY status;

-- 3. タスク完了者（task_completed = true）
SELECT '=== タスク完了者 ===' as section;
SELECT 
  COUNT(*) as タスク完了者数,
  SUM(total_amount) as 完了者出金合計
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01'
  AND task_completed = true;

-- 4. タスク完了者の詳細
SELECT '=== タスク完了者詳細 ===' as section;
SELECT 
  user_id,
  total_amount,
  personal_amount,
  referral_amount,
  status,
  task_completed
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01'
  AND task_completed = true
ORDER BY total_amount DESC;

-- 5. 上位10件
SELECT '=== 出金額上位10件 ===' as section;
SELECT 
  user_id,
  total_amount,
  personal_amount,
  referral_amount,
  status,
  task_completed
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01'
ORDER BY total_amount DESC
LIMIT 10;
