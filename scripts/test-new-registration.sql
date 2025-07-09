-- 現在のシステム状況確認

-- 1. 現在のシステム状況を確認
SELECT 
    'system_status' as check_type,
    COUNT(*) as total_users,
    COUNT(CASE WHEN coinw_uid IS NOT NULL THEN 1 END) as users_with_coinw,
    COUNT(CASE WHEN referrer_user_id IS NOT NULL THEN 1 END) as users_with_referrer
FROM users;

-- 2. 最新の5人のユーザーを確認
SELECT 
    'latest_users' as check_type,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    created_at
FROM users 
ORDER BY created_at DESC 
LIMIT 5;

-- 3. トリガーの状態確認
SELECT 
    'trigger_status' as check_type,
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';

-- 4. 登録関数の確認
SELECT 
    'function_status' as check_type,
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_name = 'handle_new_user';
