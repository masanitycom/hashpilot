-- 7A9637ユーザーのCoinW UID調査・修正

-- 1. 7A9637のauth.usersデータ確認
SELECT 
    'auth_data_7A9637' as check_type,
    au.email,
    au.raw_user_meta_data,
    au.raw_user_meta_data->>'coinw_uid' as coinw_uid_from_auth,
    au.created_at
FROM auth.users au
WHERE au.email = 'masakuma1108@gmail.com';

-- 2. CoinW UIDがある場合は同期
UPDATE users 
SET coinw_uid = auth_data.coinw_uid,
    updated_at = NOW()
FROM (
    SELECT 
        u.id,
        au.raw_user_meta_data->>'coinw_uid' as coinw_uid
    FROM users u
    JOIN auth.users au ON au.id = u.id
    WHERE u.user_id = '7A9637'
    AND au.raw_user_meta_data->>'coinw_uid' IS NOT NULL
    AND au.raw_user_meta_data->>'coinw_uid' != ''
) auth_data
WHERE users.id = auth_data.id;

-- 3. 最終確認
SELECT 
    'final_check_7A9637' as check_type,
    user_id,
    email,
    coinw_uid,
    CASE 
        WHEN coinw_uid IS NOT NULL THEN '✅ 設定済み'
        ELSE '❌ 未設定'
    END as status
FROM users
WHERE user_id = '7A9637';

-- 4. 全体の最終状況確認
SELECT 
    'overall_status' as check_type,
    COUNT(*) as total_users,
    COUNT(CASE WHEN coinw_uid IS NOT NULL THEN 1 END) as users_with_coinw_uid,
    COUNT(CASE WHEN coinw_uid IS NULL THEN 1 END) as users_without_coinw_uid,
    ROUND(
        COUNT(CASE WHEN coinw_uid IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 
        2
    ) as completion_percentage
FROM users;
