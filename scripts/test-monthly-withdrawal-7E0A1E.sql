-- ========================================
-- 月末出金処理のテスト（7E0A1E）
-- ========================================

SELECT '=== STEP 1: 現在の状態確認 ===' as section;

-- ユーザー情報
SELECT
    user_id,
    email,
    is_pegasus_exchange,
    pegasus_withdrawal_unlock_date,
    coinw_uid
FROM users
WHERE user_id = '7E0A1E';

-- 残高情報
SELECT
    user_id,
    available_usdt,
    cum_usdt,
    total_nft_count,
    manual_nft_count,
    auto_nft_count
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

-- 既存の出金申請確認
SELECT
    id,
    withdrawal_month,
    total_amount,
    status,
    task_completed
FROM monthly_withdrawals
WHERE user_id = '7E0A1E'
ORDER BY withdrawal_month DESC;

-- 既存のタスク確認
SELECT
    id,
    year,
    month,
    is_completed,
    questions_answered
FROM monthly_reward_tasks
WHERE user_id = '7E0A1E'
ORDER BY year DESC, month DESC;

SELECT '=== STEP 2: テスト準備（残高を150に設定） ===' as section;

-- 残高を150 USDTに設定
UPDATE affiliate_cycle
SET available_usdt = 150,
    last_updated = NOW()
WHERE user_id = '7E0A1E';

-- 設定確認
SELECT
    user_id,
    available_usdt,
    cum_usdt
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

SELECT '=== STEP 3: 月末処理を実行 ===' as section;

-- 今月分の月末処理を実行
SELECT * FROM process_monthly_withdrawals(DATE_TRUNC('month', CURRENT_DATE)::DATE);

SELECT '=== STEP 4: 処理結果の確認 ===' as section;

-- 出金申請が作成されたか確認
SELECT
    id,
    user_id,
    email,
    withdrawal_month,
    total_amount,
    withdrawal_method,
    withdrawal_address,
    status,
    task_completed,
    task_completed_at,
    created_at
FROM monthly_withdrawals
WHERE user_id = '7E0A1E'
ORDER BY withdrawal_month DESC
LIMIT 1;

-- タスクが作成されたか確認
SELECT
    id,
    user_id,
    year,
    month,
    is_completed,
    questions_answered,
    completed_at,
    created_at
FROM monthly_reward_tasks
WHERE user_id = '7E0A1E'
ORDER BY year DESC, month DESC
LIMIT 1;

-- 残高が変更されていないか確認（月末出金では残高は減らさない）
SELECT
    user_id,
    available_usdt,
    cum_usdt
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

SELECT '=== STEP 5: タスク完了をシミュレート ===' as section;

-- タスク完了を実行
SELECT complete_reward_task(
    '7E0A1E',
    '[
        {"question_id": "test1", "question_text": "テスト問題1", "answer": "A", "order": 1},
        {"question_id": "test2", "question_text": "テスト問題2", "answer": "B", "order": 2},
        {"question_id": "test3", "question_text": "テスト問題3", "answer": "A", "order": 3},
        {"question_id": "test4", "question_text": "テスト問題4", "answer": "B", "order": 4},
        {"question_id": "test5", "question_text": "テスト問題5", "answer": "A", "order": 5}
    ]'::JSONB
) as task_completion_result;

SELECT '=== STEP 6: タスク完了後の状態確認 ===' as section;

-- 出金申請のステータスが pending に変わったか確認
SELECT
    id,
    user_id,
    withdrawal_month,
    total_amount,
    status,
    task_completed,
    task_completed_at,
    withdrawal_method
FROM monthly_withdrawals
WHERE user_id = '7E0A1E'
ORDER BY withdrawal_month DESC
LIMIT 1;

-- タスクが完了済みになったか確認
SELECT
    id,
    user_id,
    year,
    month,
    is_completed,
    questions_answered,
    completed_at
FROM monthly_reward_tasks
WHERE user_id = '7E0A1E'
ORDER BY year DESC, month DESC
LIMIT 1;

SELECT '=== STEP 7: クリーンアップ（テストデータ削除） ===' as section;

-- テストで作成した出金申請を削除
DELETE FROM monthly_withdrawals
WHERE user_id = '7E0A1E'
  AND withdrawal_month = DATE_TRUNC('month', CURRENT_DATE)::DATE;

-- テストで作成したタスクを削除
DELETE FROM monthly_reward_tasks
WHERE user_id = '7E0A1E'
  AND year = EXTRACT(YEAR FROM CURRENT_DATE)
  AND month = EXTRACT(MONTH FROM CURRENT_DATE);

-- 残高を元に戻す（0に）
UPDATE affiliate_cycle
SET available_usdt = 0,
    last_updated = NOW()
WHERE user_id = '7E0A1E';

SELECT '=== STEP 8: クリーンアップ完了確認 ===' as section;

-- テストデータが削除されたか確認
SELECT
    COUNT(*) FILTER (WHERE withdrawal_month = DATE_TRUNC('month', CURRENT_DATE)::DATE) as current_month_withdrawals,
    COUNT(*) as total_withdrawals
FROM monthly_withdrawals
WHERE user_id = '7E0A1E';

SELECT
    COUNT(*) FILTER (WHERE year = EXTRACT(YEAR FROM CURRENT_DATE) AND month = EXTRACT(MONTH FROM CURRENT_DATE)) as current_month_tasks,
    COUNT(*) as total_tasks
FROM monthly_reward_tasks
WHERE user_id = '7E0A1E';

SELECT
    available_usdt
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ テスト完了';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '確認ポイント:';
    RAISE NOTICE '  1. 出金申請が status=on_hold で作成された';
    RAISE NOTICE '  2. タスクが is_completed=false で作成された';
    RAISE NOTICE '  3. タスク完了後、status が pending に変更された';
    RAISE NOTICE '  4. タスクが is_completed=true に変更された';
    RAISE NOTICE '  5. テストデータがクリーンアップされた';
    RAISE NOTICE '===========================================';
END $$;
