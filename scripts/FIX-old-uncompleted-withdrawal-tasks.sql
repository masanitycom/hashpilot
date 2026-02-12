-- ========================================
-- 古いタスク未完了の出金レコードを修正
-- ========================================
-- 問題: 古い月（現在月・前月以外）のmonthly_withdrawalsが
--       on_hold + task_completed = false のままになっている
--       これによりタスクポップアップがループする
--
-- 解決: 現在月・前月以外の古いレコードを pending に変更し
--       task_completed = true にする
-- ========================================

-- 1. まず対象レコードを確認
SELECT
    id,
    user_id,
    withdrawal_month,
    total_amount,
    status,
    task_completed,
    created_at
FROM monthly_withdrawals
WHERE status = 'on_hold'
  AND task_completed = false
  AND withdrawal_month < (DATE_TRUNC('month', NOW() AT TIME ZONE 'Asia/Tokyo') - INTERVAL '1 month')::DATE
ORDER BY withdrawal_month DESC, user_id;

-- 2. 古い出金レコードをpendingに更新（タスク完了扱い）
-- ★ 実行前に上のSELECTで対象を確認してください
/*
UPDATE monthly_withdrawals
SET
    status = 'pending',
    task_completed = true,
    task_completed_at = NOW(),
    updated_at = NOW()
WHERE status = 'on_hold'
  AND task_completed = false
  AND withdrawal_month < (DATE_TRUNC('month', NOW() AT TIME ZONE 'Asia/Tokyo') - INTERVAL '1 month')::DATE;
*/

-- 3. 対応するmonthly_reward_tasksも完了に更新
-- ★ 実行前に対象を確認してください
/*
UPDATE monthly_reward_tasks mrt
SET
    is_completed = true,
    completed_at = NOW(),
    updated_at = NOW()
FROM monthly_withdrawals mw
WHERE mrt.user_id = mw.user_id
  AND mrt.year = EXTRACT(YEAR FROM mw.withdrawal_month::date)
  AND mrt.month = EXTRACT(MONTH FROM mw.withdrawal_month::date)
  AND mrt.is_completed = false
  AND mw.withdrawal_month < (DATE_TRUNC('month', NOW() AT TIME ZONE 'Asia/Tokyo') - INTERVAL '1 month')::DATE;
*/

-- 4. 修正後の確認
SELECT
    id,
    user_id,
    withdrawal_month,
    total_amount,
    status,
    task_completed
FROM monthly_withdrawals
WHERE status = 'on_hold'
  AND task_completed = false
ORDER BY withdrawal_month DESC, user_id;
