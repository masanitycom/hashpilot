-- 出金申請システムの全体フロー確認

SELECT '=== 1. 出金申請を生成する関数 ===' as section;

SELECT
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE '%withdrawal%'
ORDER BY routine_name;

SELECT '=== 2. monthly_reward_tasks テーブル ===' as section;

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'monthly_reward_tasks'
ORDER BY ordinal_position;

SELECT '=== 3. タスクの最新データ ===' as section;

SELECT *
FROM monthly_reward_tasks
ORDER BY created_at DESC
LIMIT 5;

SELECT '=== 4. 出金申請のステータス一覧 ===' as section;

SELECT DISTINCT status
FROM monthly_withdrawals;

SELECT '=== 5. process_monthly_withdrawals 関数の存在確認 ===' as section;

SELECT EXISTS (
    SELECT 1
    FROM information_schema.routines
    WHERE routine_schema = 'public'
      AND routine_name = 'process_monthly_withdrawals'
) as function_exists;

SELECT '=== 6. ペガサス取引所ユーザー数 ===' as section;

SELECT
    COUNT(*) as total_pegasus_users,
    COUNT(*) FILTER (WHERE pegasus_withdrawal_unlock_date IS NOT NULL) as users_with_unlock_date,
    COUNT(*) FILTER (WHERE pegasus_withdrawal_unlock_date > CURRENT_DATE) as currently_locked
FROM users
WHERE is_pegasus_exchange = true;
