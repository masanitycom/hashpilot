-- 登録システムの状態を確認するスクリプト

-- 1. 認証ユーザーテーブルの状態確認
SELECT 
    'auth.users' as table_name,
    COUNT(*) as total_count,
    COUNT(CASE WHEN email_confirmed_at IS NOT NULL THEN 1 END) as confirmed_count,
    COUNT(CASE WHEN created_at > NOW() - INTERVAL '1 hour' THEN 1 END) as recent_registrations
FROM auth.users;

-- 2. publicユーザーテーブルの状態確認
SELECT 
    'public.users' as table_name,
    COUNT(*) as total_count,
    COUNT(CASE WHEN is_active = true THEN 1 END) as active_count,
    COUNT(CASE WHEN created_at > NOW() - INTERVAL '1 hour' THEN 1 END) as recent_users
FROM public.users;

-- 3. トリガー関数の存在確認
SELECT 
    routine_name,
    routine_type,
    created
FROM information_schema.routines 
WHERE routine_name = 'handle_new_user';

-- 4. トリガーの存在確認
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    trigger_schema
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- 5. RLSポリシーの確認
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'users';

-- 6. 最近の登録エラーをチェック（もしログテーブルがあれば）
-- SELECT * FROM auth.audit_log_entries 
-- WHERE created_at > NOW() - INTERVAL '1 hour' 
-- ORDER BY created_at DESC 
-- LIMIT 10;

-- 7. データベース接続とアクセス権限の確認
SELECT 
    current_user as current_db_user,
    current_database() as current_db,
    version() as postgres_version;
