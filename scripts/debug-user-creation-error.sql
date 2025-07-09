-- ユーザー作成エラーの原因を調査

-- 1. 現在のトリガーの状態を確認
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement,
    action_timing
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- 2. handle_new_user関数の定義を確認
SELECT 
    routine_name,
    routine_definition,
    routine_type
FROM information_schema.routines 
WHERE routine_name = 'handle_new_user';

-- 3. usersテーブルの構造を確認
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 4. 最近のエラーログを確認（もしあれば）
SELECT 
    created_at,
    level,
    msg,
    metadata
FROM auth.audit_log_entries 
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC
LIMIT 10;

-- 5. 現在のusersテーブルのサンプルデータ
SELECT 
    id,
    user_id,
    email,
    referrer_user_id,
    coinw_uid,
    created_at
FROM users 
ORDER BY created_at DESC 
LIMIT 5;
