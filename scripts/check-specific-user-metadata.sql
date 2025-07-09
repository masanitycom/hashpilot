-- 特定ユーザーの詳細情報を確認

-- 1. Y9FVT1ユーザーの詳細情報
SELECT 
    u.user_id,
    u.email,
    u.referrer_user_id,
    u.coinw_uid,
    u.created_at as user_created,
    au.raw_user_meta_data,
    au.created_at as auth_created
FROM users u
LEFT JOIN auth.users au ON u.id = au.id
WHERE u.user_id = 'Y9FVT1';

-- 2. 紹介者2BF53Bの情報
SELECT 
    u.user_id,
    u.email,
    u.referrer_user_id,
    u.coinw_uid,
    u.created_at
FROM users u
WHERE u.user_id = '2BF53B';

-- 3. 紹介関係の確認
SELECT 
    referrer.user_id as referrer_id,
    referrer.email as referrer_email,
    referred.user_id as referred_id,
    referred.email as referred_email,
    referred.coinw_uid,
    referred.created_at
FROM users referrer
JOIN users referred ON referrer.user_id = referred.referrer_user_id
WHERE referrer.user_id = '2BF53B';
