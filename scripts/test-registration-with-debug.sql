-- 登録システムのテスト（デバッグ付き）

-- 1. 現在のシステム状態を確認
SELECT 'system_check' as check_type, 'Starting registration system test' as message;

-- 2. トリガーの存在確認
SELECT 
    'trigger_status' as check_type,
    CASE 
        WHEN COUNT(*) > 0 THEN 'EXISTS' 
        ELSE 'MISSING' 
    END as status,
    COUNT(*) as count
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- 3. 関数の存在確認
SELECT 
    'function_status' as check_type,
    CASE 
        WHEN COUNT(*) > 0 THEN 'EXISTS' 
        ELSE 'MISSING' 
    END as status,
    COUNT(*) as count
FROM information_schema.routines 
WHERE routine_name = 'handle_new_user';

-- 4. public.usersテーブルの構造確認
SELECT 
    'table_structure' as check_type,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'users' 
AND column_name IN ('id', 'user_id', 'email', 'referrer_user_id', 'coinw_uid')
ORDER BY column_name;

-- 5. 最近のauth.usersデータ
SELECT 
    'recent_auth_users' as check_type,
    id,
    email,
    raw_user_meta_data,
    created_at
FROM auth.users 
ORDER BY created_at DESC 
LIMIT 3;

-- 6. 最近のpublic.usersデータ
SELECT 
    'recent_public_users' as check_type,
    user_id,
    email,
    referrer_user_id,
    coinw_uid,
    created_at
FROM public.users 
ORDER BY created_at DESC 
LIMIT 3;

-- 7. システム統計
SELECT 
    'system_stats' as check_type,
    COUNT(*) as total_users,
    COUNT(referrer_user_id) as users_with_referrer,
    COUNT(coinw_uid) as users_with_coinw_uid,
    ROUND(
        (COUNT(CASE WHEN referrer_user_id IS NOT NULL AND coinw_uid IS NOT NULL THEN 1 END) * 100.0 / NULLIF(COUNT(*), 0)), 
        2
    ) as complete_data_percentage
FROM public.users;

SELECT 'test_ready' as check_type, 'System is ready for testing' as message;
