-- CoinW UID同期の安全な修正スクリプト

-- 1. auth.usersからusersテーブルへのCoinW UID同期
UPDATE users 
SET coinw_uid = au.raw_user_meta_data->>'coinw_uid',
    updated_at = NOW()
FROM auth.users au
WHERE users.id = au.id
AND au.raw_user_meta_data->>'coinw_uid' IS NOT NULL
AND (users.coinw_uid IS NULL OR users.coinw_uid = '');

-- 2. 同期結果の確認
SELECT 
    'sync_result' as check_type,
    COUNT(*) as total_synced
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.coinw_uid = au.raw_user_meta_data->>'coinw_uid'
AND u.coinw_uid IS NOT NULL;

-- 3. まだ同期されていないユーザーの確認
SELECT 
    'remaining_unsync' as check_type,
    u.user_id,
    u.email,
    u.coinw_uid as users_coinw_uid,
    au.raw_user_meta_data->>'coinw_uid' as auth_coinw_uid
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE (u.coinw_uid IS NULL OR u.coinw_uid = '')
AND au.raw_user_meta_data->>'coinw_uid' IS NOT NULL;
