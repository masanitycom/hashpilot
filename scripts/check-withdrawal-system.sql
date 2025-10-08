-- 出金申請システムの確認

SELECT '=== monthly_withdrawals テーブル構造 ===' as section;

SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'monthly_withdrawals'
ORDER BY ordinal_position;

SELECT '=== monthly_withdrawals の外部キー ===' as section;

SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name
  AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name
  AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'monthly_withdrawals';

SELECT '=== monthly_withdrawals のデータサンプル ===' as section;

SELECT * FROM monthly_withdrawals LIMIT 5;

SELECT '=== monthly_reward_tasks テーブル構造 ===' as section;

SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'monthly_reward_tasks'
ORDER BY ordinal_position;

SELECT '=== monthly_reward_tasks のデータサンプル ===' as section;

SELECT * FROM monthly_reward_tasks ORDER BY created_at DESC LIMIT 5;

SELECT '=== ペガサス関連カラム確認 ===' as section;

SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'users'
  AND column_name LIKE '%pegasus%';
