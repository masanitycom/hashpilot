-- 実際の登録フローをテスト

-- 1. 現在のユーザー状況を確認
SELECT 
    'current_users_before_test' as check_type,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    created_at
FROM users 
ORDER BY created_at DESC 
LIMIT 5;

-- 2. auth.usersの最新メタデータを確認
SELECT 
    'auth_users_metadata' as check_type,
    email,
    raw_user_meta_data,
    created_at
FROM auth.users 
ORDER BY created_at DESC 
LIMIT 3;

-- 3. トリガーが正常に動作しているか確認
SELECT 
    'trigger_verification' as check_type,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- 4. 関数の詳細を確認
SELECT 
    'function_details' as check_type,
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines 
WHERE routine_name = 'handle_new_user';
