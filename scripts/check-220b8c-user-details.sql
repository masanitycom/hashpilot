-- 220B8Cユーザーの詳細確認

-- 1. usersテーブルでの220B8Cユーザー情報
SELECT 
    'users_table_data' as check_type,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    is_active,
    created_at
FROM users 
WHERE user_id = '220B8C';

-- 2. auth.usersテーブルでの対応するユーザー情報
SELECT 
    'auth_users_data' as check_type,
    id,
    email,
    raw_user_meta_data,
    created_at
FROM auth.users 
WHERE email = 'masataka.tak+63@gmail.com';

-- 3. 最近の登録ユーザー比較
SELECT 
    'recent_users_comparison' as check_type,
    u.user_id,
    u.email,
    u.coinw_uid,
    u.referrer_user_id,
    au.raw_user_meta_data->>'coinw_uid' as meta_coinw,
    au.raw_user_meta_data->>'referrer' as meta_referrer,
    u.created_at
FROM users u
JOIN auth.users au ON u.user_id = au.id::text
WHERE u.created_at >= NOW() - INTERVAL '24 hours'
ORDER BY u.created_at DESC;
