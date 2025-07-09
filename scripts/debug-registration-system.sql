-- 登録システムのデバッグ

-- 1. handle_new_user関数の内容確認
SELECT 
    'function_definition' as check_type,
    prosrc as function_body
FROM pg_proc 
WHERE proname = 'handle_new_user';

-- 2. トリガーの状態確認
SELECT 
    'trigger_status' as check_type,
    trigger_name,
    event_manipulation,
    action_statement,
    action_timing
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- 3. 最近のユーザー登録状況
SELECT 
    'recent_registrations' as check_type,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    created_at
FROM users 
WHERE created_at >= NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;
