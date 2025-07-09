-- CoinW UID表示問題の調査（修正版）

-- 1. auth.usersテーブルの構造確認
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'auth' AND table_name = 'users'
ORDER BY ordinal_position;

-- 2. 該当ユーザーのauth.users情報確認
SELECT 
    id,
    email,
    created_at,
    raw_user_meta_data,
    raw_app_meta_data
FROM auth.users 
WHERE email = 'masataka.tak+22@gmail.com';

-- 3. publicテーブルのユーザー情報確認
SELECT 
    user_id,
    email,
    coinw_uid,
    created_at
FROM users 
WHERE email = 'masataka.tak+22@gmail.com';

-- 4. 購入レコードとユーザー情報の結合確認
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

-- 5. admin_purchases_viewの現在の定義確認
SELECT pg_get_viewdef('admin_purchases_view');

-- 6. 全ユーザーのCoinW UID状況確認
SELECT 
    COUNT(*) as total_users,
    COUNT(coinw_uid) as users_with_coinw_uid,
    COUNT(*) - COUNT(coinw_uid) as users_without_coinw_uid
FROM users;
