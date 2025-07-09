-- 登録トリガーの詳細デバッグ

-- 1. トリガーの存在確認
SELECT 
    'trigger_check' as check_type,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- 2. 関数の存在確認
SELECT 
    'function_check' as check_type,
    routine_name,
    routine_type,
    data_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'handle_new_user';

-- 3. 最近のauth.usersデータ
SELECT 
    'auth_users_recent' as check_type,
    id,
    email,
    raw_user_meta_data,
    created_at
FROM auth.users 
ORDER BY created_at DESC 
LIMIT 5;

-- 4. 最近のusersテーブルデータ
SELECT 
    'users_table_recent' as check_type,
    user_id,
    email,
    referrer_user_id,
    coinw_uid,
    created_at
FROM users 
ORDER BY created_at DESC 
LIMIT 5;

-- 5. テーブル構造確認
SELECT 
    'users_table_structure' as check_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'users' 
ORDER BY ordinal_position;
