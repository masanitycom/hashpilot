-- ========================================
-- 現在のシステム状態確認
-- 移行前の安全確認
-- ========================================

SELECT '=== 1. withdrawal_requests テーブルの使用状況 ===' as section;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'withdrawal_requests') THEN
        RAISE NOTICE '⚠️ withdrawal_requests テーブルが存在します（個別出金システム）';

        -- 件数を表示
        RAISE NOTICE '  - 総件数: %', (SELECT COUNT(*) FROM withdrawal_requests);
        RAISE NOTICE '  - 保留中: %', (SELECT COUNT(*) FROM withdrawal_requests WHERE status = 'pending');
    ELSE
        RAISE NOTICE '✅ withdrawal_requests テーブルは存在しません（個別出金システムは未使用）';
    END IF;
END $$;

SELECT '=== 2. monthly_withdrawals テーブルの状態 ===' as section;

-- 月末出金申請の件数確認
SELECT
    COUNT(*) as total_withdrawals,
    COUNT(*) FILTER (WHERE status = 'pending') as pending,
    COUNT(*) FILTER (WHERE status = 'on_hold') as on_hold,
    COUNT(*) FILTER (WHERE status = 'completed') as completed,
    COUNT(*) FILTER (WHERE task_completed = true) as task_completed_count,
    COUNT(*) FILTER (WHERE task_completed = false) as task_pending_count
FROM monthly_withdrawals;

SELECT '=== 3. monthly_reward_tasks テーブルの状態 ===' as section;

-- 月末タスクの件数確認
SELECT
    COUNT(*) as total_tasks,
    COUNT(*) FILTER (WHERE is_completed = true) as completed,
    COUNT(*) FILTER (WHERE is_completed = false) as pending
FROM monthly_reward_tasks;

SELECT '=== 4. 出金対象ユーザー（available_usdt >= 100） ===' as section;

-- 現在出金対象となるユーザー数
SELECT
    COUNT(*) as eligible_users,
    SUM(available_usdt) as total_amount,
    COUNT(*) FILTER (WHERE
        COALESCE((SELECT is_pegasus_exchange FROM users WHERE users.user_id = affiliate_cycle.user_id), FALSE) = TRUE
        AND (
            (SELECT pegasus_withdrawal_unlock_date FROM users WHERE users.user_id = affiliate_cycle.user_id) IS NULL
            OR CURRENT_DATE < (SELECT pegasus_withdrawal_unlock_date FROM users WHERE users.user_id = affiliate_cycle.user_id)
        )
    ) as pegasus_locked_users
FROM affiliate_cycle
WHERE available_usdt >= 100;

SELECT '=== 5. ペガサス交換ユーザーの状態 ===' as section;

-- ペガサス交換ユーザーの詳細
SELECT
    user_id,
    email,
    is_pegasus_exchange,
    pegasus_withdrawal_unlock_date,
    CASE
        WHEN pegasus_withdrawal_unlock_date IS NULL THEN '未設定（永久ロック）'
        WHEN CURRENT_DATE < pegasus_withdrawal_unlock_date THEN FORMAT('ロック中（%sまで）', pegasus_withdrawal_unlock_date)
        ELSE '解禁済み'
    END as lock_status,
    (SELECT available_usdt FROM affiliate_cycle WHERE affiliate_cycle.user_id = users.user_id) as available_usdt
FROM users
WHERE is_pegasus_exchange = true
ORDER BY pegasus_withdrawal_unlock_date NULLS FIRST;

SELECT '=== 6. 関数の存在確認 ===' as section;

-- 既存の出金関連関数
SELECT
    routine_name,
    routine_type,
    CASE
        WHEN routine_name = 'process_monthly_withdrawals' THEN '✅ 月末出金処理（新）'
        WHEN routine_name = 'complete_reward_task' THEN '✅ タスク完了処理'
        WHEN routine_name = 'create_withdrawal_request' THEN '⚠️ 個別出金申請（削除予定）'
        WHEN routine_name = 'process_withdrawal_request' THEN '⚠️ 個別出金承認（削除予定）'
        WHEN routine_name = 'get_japan_date' THEN '✅ 日本時間ヘルパー'
        ELSE '📋 その他'
    END as description
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND (
      routine_name LIKE '%withdrawal%'
      OR routine_name LIKE '%reward%task%'
      OR routine_name LIKE '%japan%'
  )
ORDER BY routine_name;

SELECT '=== 7. 日本時間の確認 ===' as section;

-- 日本時間ヘルパー関数のテスト
DO $$
DECLARE
    v_has_japan_helpers BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM information_schema.routines
        WHERE routine_name = 'get_japan_date'
    ) INTO v_has_japan_helpers;

    IF v_has_japan_helpers THEN
        RAISE NOTICE '✅ 日本時間ヘルパー関数が存在します';
        RAISE NOTICE '  現在の日本時間: %', (SELECT get_japan_date());
        RAISE NOTICE '  今月の月末: %', (SELECT get_month_end(get_japan_date()));
        RAISE NOTICE '  今日は月末？: %', (SELECT is_month_end());
    ELSE
        RAISE NOTICE '❌ 日本時間ヘルパー関数が存在しません';
        RAISE NOTICE '  → scripts/add-japan-timezone-helpers.sql を実行してください';
    END IF;
END $$;

SELECT '=== 8. foreign key制約の確認 ===' as section;

-- monthly_withdrawals の外部キー確認
SELECT
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'monthly_withdrawals';

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ システム状態確認完了';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '次のステップ:';
    RAISE NOTICE '  1. 上記の結果を確認';
    RAISE NOTICE '  2. withdrawal_requests に保留中の申請がないか確認';
    RAISE NOTICE '  3. MIGRATION_PLAN.md の手順に従って移行';
    RAISE NOTICE '===========================================';
END $$;
