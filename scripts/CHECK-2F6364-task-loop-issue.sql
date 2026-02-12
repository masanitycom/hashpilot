-- ========================================
-- 2F6364 タスクループ問題の調査
-- ========================================

-- 1. monthly_withdrawals の状態確認
SELECT
    id,
    withdrawal_month,
    total_amount,
    status,
    task_completed,
    task_completed_at,
    created_at
FROM monthly_withdrawals
WHERE user_id = '2F6364'
ORDER BY withdrawal_month DESC;

-- 2. monthly_reward_tasks の状態確認
SELECT
    id,
    user_id,
    year,
    month,
    is_completed,
    completed_at,
    created_at
FROM monthly_reward_tasks
WHERE user_id = '2F6364'
ORDER BY year DESC, month DESC;

-- 3. 全ユーザーで同様の問題があるか確認
-- （on_hold かつ task_completed = false の出金がある）
SELECT
    mw.user_id,
    mw.withdrawal_month,
    mw.status,
    mw.task_completed,
    mrt.is_completed as task_is_completed,
    mrt.year,
    mrt.month
FROM monthly_withdrawals mw
LEFT JOIN monthly_reward_tasks mrt
    ON mw.user_id = mrt.user_id
    AND EXTRACT(YEAR FROM mw.withdrawal_month::date) = mrt.year
    AND EXTRACT(MONTH FROM mw.withdrawal_month::date) = mrt.month
WHERE mw.status = 'on_hold'
  AND mw.task_completed = false
ORDER BY mw.withdrawal_month DESC, mw.user_id;

-- 4. 問題: monthly_reward_tasks が完了済み(is_completed=true)なのに
--    monthly_withdrawals が未完了(task_completed=false)のケースを探す
SELECT
    mw.user_id,
    mw.withdrawal_month,
    mw.status,
    mw.task_completed,
    mrt.is_completed as task_record_completed,
    mrt.completed_at
FROM monthly_withdrawals mw
INNER JOIN monthly_reward_tasks mrt
    ON mw.user_id = mrt.user_id
    AND EXTRACT(YEAR FROM mw.withdrawal_month::date) = mrt.year
    AND EXTRACT(MONTH FROM mw.withdrawal_month::date) = mrt.month
WHERE mw.status = 'on_hold'
  AND mw.task_completed = false
  AND mrt.is_completed = true
ORDER BY mw.user_id;
