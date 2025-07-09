-- CoinW UID表示問題の調査

-- 1. 該当ユーザーのCoinW UID確認
SELECT 
    user_id,
    email,
    coinw_uid,
    created_at,
    user_metadata,
    raw_user_meta_data
FROM auth.users 
WHERE email = 'masataka.tak+22@gmail.com';

-- 2. publicテーブルのユーザー情報確認
SELECT 
    user_id,
    email,
    coinw_uid,
    created_at
FROM users 
WHERE email = 'masataka.tak+22@gmail.com';

-- 3. 購入レコードとユーザー情報の結合確認
SELECT 
    p.id as purchase_id,
    p.user_id,
    u.email,
    u.coinw_uid,
    p.amount_usd,
    p.created_at as purchase_date
FROM purchases p
LEFT JOIN users u ON p.user_id = u.user_id
WHERE u.email = 'masataka.tak+22@gmail.com';

-- 4. admin_purchases_viewの確認
SELECT * FROM admin_purchases_view 
WHERE email = 'masataka.tak+22@gmail.com';

-- 5. 全ユーザーのCoinW UID状況確認
SELECT 
    COUNT(*) as total_users,
    COUNT(coinw_uid) as users_with_coinw_uid,
    COUNT(*) - COUNT(coinw_uid) as users_without_coinw_uid
FROM users;

-- 6. 最近の登録ユーザーのCoinW UID確認
SELECT 
    user_id,
    email,
    coinw_uid,
    created_at
FROM users 
ORDER BY created_at DESC 
LIMIT 10;
