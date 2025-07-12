-- delete_user_safely関数の存在と動作確認

-- 1. 関数が存在するかチェック
SELECT 
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as arguments,
    p.oid,
    pg_get_functiondef(p.oid) as function_definition_exists
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'delete_user_safely'
AND n.nspname = 'public';

-- 2. 関数の権限確認
SELECT 
    grantee,
    privilege_type
FROM information_schema.routine_privileges
WHERE routine_name = 'delete_user_safely'
AND routine_schema = 'public';

-- 3. 削除可能なテストユーザーで実際にテスト
-- 注意: 実際に削除されます
WITH safe_test_user AS (
    SELECT user_id, email 
    FROM users 
    WHERE email LIKE '%test%' 
       OR (created_at > NOW() - INTERVAL '1 day' AND COALESCE(total_purchases, 0) = 0)
    LIMIT 1
)
SELECT 
    'テスト対象ユーザー:' as info,
    stu.user_id,
    stu.email,
    'テスト実行コマンド:' as command,
    'SELECT * FROM delete_user_safely(''' || stu.user_id || ''', ''masataka.tak@gmail.com'');' as sql_command
FROM safe_test_user stu;

-- 4. エラーが発生したユーザーの確認
SELECT 
    id as uuid_id,
    user_id as short_id,
    email,
    total_purchases,
    has_approved_nft,
    EXISTS(SELECT 1 FROM affiliate_cycle WHERE user_id = u.user_id) as has_affiliate_cycle
FROM users u
WHERE id::text = '3b157508-937c-48d7-95db-82b0574b8c4f';