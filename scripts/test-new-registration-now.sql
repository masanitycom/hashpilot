-- 今すぐ新規登録をテスト

-- 1. システム状態確認
SELECT 'SYSTEM CHECK' as step, 'Checking registration system status' as message;

-- 2. トリガー確認
SELECT 
    'TRIGGER_CHECK' as check_type,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created'
AND event_object_table = 'users'
AND event_object_schema = 'auth';

-- 3. 関数確認
SELECT 
    'FUNCTION_CHECK' as check_type,
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'handle_new_user'
AND routine_schema = 'public';

-- 4. テーブル構造確認
SELECT 
    'TABLE_STRUCTURE' as check_type,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'users'
AND column_name IN ('user_id', 'referrer_user_id', 'coinw_uid', 'email')
ORDER BY ordinal_position;

-- 5. 現在のユーザー統計
SELECT 
    'SYSTEM_STATS' as check_type,
    COUNT(*) as total_users,
    COUNT(referrer_user_id) as users_with_referrer,
    COUNT(coinw_uid) as users_with_coinw,
    ROUND(
        (COUNT(CASE WHEN referrer_user_id IS NOT NULL AND coinw_uid IS NOT NULL THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0))
    ) as success_rate_percentage
FROM public.users;

-- 6. 最新ユーザー（最大5件）
SELECT 
    'RECENT_USERS' as check_type,
    user_id,
    email,
    referrer_user_id,
    coinw_uid,
    created_at
FROM public.users 
ORDER BY created_at DESC 
LIMIT 5;

SELECT 'READY FOR TESTING' as step, 'System is ready - please test registration now!' as message;
