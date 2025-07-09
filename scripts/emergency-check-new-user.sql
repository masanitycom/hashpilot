-- 緊急：新規登録ユーザー 220B8C の確認

-- 1. 新規ユーザーの基本情報確認
SELECT 
    'new_user_basic_info' as check_type,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    is_active,
    created_at
FROM users 
WHERE user_id = '220B8C' OR email = 'masataka.tak+63@gmail.com';

-- 2. auth.usersテーブルでの確認（正しい列名を使用）
SELECT 
    'auth_user_data' as check_type,
    id,
    email,
    email_confirmed_at,
    created_at,
    raw_user_meta_data
FROM auth.users 
WHERE email = 'masataka.tak+63@gmail.com'
ORDER BY created_at DESC;

-- 3. 最新の5人の登録ユーザーを確認
SELECT 
    'recent_registrations' as check_type,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    created_at
FROM users 
ORDER BY created_at DESC 
LIMIT 5;

-- 4. トリガーの動作状況確認
SELECT 
    'trigger_status' as check_type,
    t.tgname as trigger_name,
    CASE t.tgenabled 
        WHEN 'O' THEN '✅ 有効'
        ELSE '❌ 無効'
    END as status,
    p.proname as function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
JOIN pg_class c ON t.tgrelid = c.oid
WHERE t.tgname = 'on_auth_user_created';

-- 5. handle_new_user関数の確認
SELECT 
    'function_exists' as check_type,
    proname as function_name,
    LENGTH(prosrc) as function_length
FROM pg_proc 
WHERE proname = 'handle_new_user';
