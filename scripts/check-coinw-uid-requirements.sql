-- CoinW UIDの必須チェックと現在の状況確認

-- 1. 全ユーザーのCoinW UID状況
SELECT 
    COUNT(*) as total_users,
    COUNT(coinw_uid) as users_with_coinw_uid,
    COUNT(*) - COUNT(coinw_uid) as users_without_coinw_uid,
    ROUND(COUNT(coinw_uid) * 100.0 / COUNT(*), 2) as coinw_uid_percentage
FROM users;

-- 2. 購入者のCoinW UID状況
SELECT 
    p.user_id,
    u.email,
    u.coinw_uid,
    p.amount_usd,
    p.payment_status,
    p.admin_approved,
    p.created_at
FROM purchases p
LEFT JOIN users u ON p.user_id = u.user_id
ORDER BY p.created_at DESC;

-- 3. CoinW UIDが未入力の購入者
SELECT 
    p.user_id,
    u.email,
    p.amount_usd,
    p.payment_status,
    p.created_at
FROM purchases p
LEFT JOIN users u ON p.user_id = u.user_id
WHERE u.coinw_uid IS NULL OR u.coinw_uid = ''
ORDER BY p.created_at DESC;

-- 4. 紹介者とCoinW UIDの関係
SELECT 
    u.user_id,
    u.email,
    u.referrer_user_id,
    u.coinw_uid,
    CASE 
        WHEN u.referrer_user_id IS NOT NULL THEN '紹介経由'
        ELSE '直接登録'
    END as registration_type,
    u.created_at
FROM users u
ORDER BY u.created_at DESC;
