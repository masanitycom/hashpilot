-- ========================================
-- 月末出金専用システムへの移行
-- 個別出金申請システムを削除
-- ========================================

-- STEP 1: 新しい関数を適用
\i /mnt/d/HASHPILOT/scripts/create-process-monthly-withdrawals.sql

-- STEP 2: 個別出金申請システムの削除確認
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '⚠️ 個別出金申請システムの削除確認';
    RAISE NOTICE '===========================================';

    -- withdrawal_requests テーブルの件数確認
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'withdrawal_requests') THEN
        RAISE NOTICE 'withdrawal_requests テーブルが存在します';
        RAISE NOTICE '  - レコード数: %', (SELECT COUNT(*) FROM withdrawal_requests);
        RAISE NOTICE '  - 保留中: %', (SELECT COUNT(*) FROM withdrawal_requests WHERE status = 'pending');
    END IF;
END $$;

-- STEP 3: 個別出金申請関連の関数を削除
DROP FUNCTION IF EXISTS create_withdrawal_request(TEXT, NUMERIC, TEXT, TEXT);
DROP FUNCTION IF EXISTS process_withdrawal_request(UUID, TEXT, TEXT, TEXT, TEXT);
DROP FUNCTION IF EXISTS get_user_withdrawal_history(TEXT, INTEGER);
DROP FUNCTION IF EXISTS get_withdrawal_requests_admin(TEXT, INTEGER);

-- STEP 4: withdrawal_requests テーブルを削除（必要に応じてコメントアウト解除）
-- ⚠️ 本番環境で実行する前に必ずバックアップを取得してください
-- DROP TABLE IF EXISTS withdrawal_requests CASCADE;

DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '⚠️ withdrawal_requests テーブルの削除';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '本番環境では慎重に実行してください';
    RAISE NOTICE '削除する場合は、上記のDROP TABLEコメントを解除してください';
END $$;

-- STEP 5: 月末出金システムの確認
SELECT '=== monthly_withdrawals テーブル ===' as section;
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'monthly_withdrawals'
ORDER BY ordinal_position;

SELECT '=== monthly_reward_tasks テーブル ===' as section;
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'monthly_reward_tasks'
ORDER BY ordinal_position;

SELECT '=== 月末出金関連関数 ===' as section;
SELECT
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN ('process_monthly_withdrawals', 'complete_reward_task', 'get_random_questions')
ORDER BY routine_name;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ 月末出金専用システムへの移行完了';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '変更内容:';
    RAISE NOTICE '  ✅ process_monthly_withdrawals 関数を作成';
    RAISE NOTICE '  ✅ complete_reward_task 関数を更新';
    RAISE NOTICE '  ✅ 個別出金申請関数を削除';
    RAISE NOTICE '  ⚠️ withdrawal_requests テーブルは残存（必要に応じて削除）';
    RAISE NOTICE '';
    RAISE NOTICE '次のステップ:';
    RAISE NOTICE '  1. フロントエンドでタスクポップアップが正しく動作するか確認';
    RAISE NOTICE '  2. 月末処理をテスト実行';
    RAISE NOTICE '  3. withdrawal_requests テーブルの削除を検討';
    RAISE NOTICE '===========================================';
END $$;
