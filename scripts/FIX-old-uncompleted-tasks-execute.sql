-- ========================================
-- 古いタスク未完了出金レコードの修正（実行用）
-- ========================================
-- 対象: 2025年11月、2025年12月の on_hold + task_completed = false レコード
-- 対象ユーザー: 2C44D5, 794682, YBVQ9D, 361CF6
-- ========================================

-- 1. 修正前の確認
SELECT
    user_id,
    withdrawal_month,
    total_amount,
    status,
    task_completed
FROM monthly_withdrawals
WHERE status = 'on_hold'
  AND task_completed = false
  AND withdrawal_month IN ('2025-11-01', '2025-12-01')
ORDER BY user_id, withdrawal_month;

-- 2. 古い出金レコードをpending + task_completed = trueに更新
UPDATE monthly_withdrawals
SET
    status = 'pending',
    task_completed = true,
    task_completed_at = NOW(),
    updated_at = NOW()
WHERE status = 'on_hold'
  AND task_completed = false
  AND withdrawal_month IN ('2025-11-01', '2025-12-01');

-- 3. 修正後の確認
SELECT
    user_id,
    withdrawal_month,
    total_amount,
    status,
    task_completed
FROM monthly_withdrawals
WHERE withdrawal_month IN ('2025-11-01', '2025-12-01')
ORDER BY user_id, withdrawal_month;

-- 4. 残りのon_hold確認（2026/01のみが残るべき）
SELECT
    user_id,
    withdrawal_month,
    status,
    task_completed
FROM monthly_withdrawals
WHERE status = 'on_hold'
  AND task_completed = false
ORDER BY withdrawal_month, user_id;
