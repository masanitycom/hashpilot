-- OOCJ16ユーザーのCoinW UID調査と全体修正

-- 1. OOCJ16ユーザーの詳細調査
SELECT 
    'OOCJ16_auth_data' as check_type,
    au.id,
    au.email,
    au.raw_user_meta_data,
    au.raw_user_meta_data->>'coinw_uid' as coinw_uid_from_auth,
    au.created_at
FROM auth.users au
WHERE au.email = 'masashitakakuwa9@gmail.com';

-- 2. OOCJ16のpublic.usersデータ確認
SELECT 
    'OOCJ16_public_data' as check_type,
    u.user_id,
    u.email,
    u.coinw_uid,
    u.referrer_user_id,
    u.created_at
FROM users u
WHERE u.user_id = 'OOCJ16' OR u.email = 'masashitakakuwa9@gmail.com';

-- 3. 全ユーザーのCoinW UID同期状況確認
SELECT 
    'coinw_uid_sync_status' as check_type,
    COUNT(*) as total_users,
    COUNT(CASE WHEN u.coinw_uid IS NOT NULL THEN 1 END) as users_with_coinw_uid,
    COUNT(CASE WHEN u.coinw_uid IS NULL THEN 1 END) as users_without_coinw_uid
FROM users u;

-- 4. auth.usersにあってpublic.usersにないCoinW UID
SELECT 
    'missing_coinw_uids' as check_type,
    u.user_id,
    u.email,
    u.coinw_uid as current_coinw_uid,
    au.raw_user_meta_data->>'coinw_uid' as auth_coinw_uid
FROM users u
JOIN auth.users au ON au.id = u.id
WHERE u.coinw_uid IS NULL 
AND au.raw_user_meta_data->>'coinw_uid' IS NOT NULL;
