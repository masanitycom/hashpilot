-- 完全なテーブル構造とデータ確認

-- 1. auth.usersテーブルの詳細構造
SELECT 'auth_users_structure' as info_type, column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'auth' AND table_name = 'users'
ORDER BY ordinal_position;

-- 2. public.usersテーブルの詳細構造  
SELECT 'public_users_structure' as info_type, column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' AND table_name = 'users'
ORDER BY ordinal_position;

-- 3. V1SPIYユーザーの完全情報（auth.users）
SELECT 
    'v1spiy_auth_data' as info_type,
    id,
    email,
    raw_user_meta_data,
    created_at
FROM auth.users 
WHERE email = 'masataka.tak+22@gmail.com';

-- 4. V1SPIYユーザーの完全情報（public.users）
SELECT 
    'v1spiy_public_data' as info_type,
    id,
    user_id,
    email,
    coinw_uid,
    created_at
FROM users 
WHERE email = 'masataka.tak+22@gmail.com';

-- 5. CoinW UIDが未設定のユーザー詳細
SELECT 
    'missing_coinw_users' as info_type,
    user_id,
    email,
    coinw_uid,
    created_at
FROM users 
WHERE coinw_uid IS NULL
ORDER BY created_at DESC;

-- 6. 最新の購入レコード（V1SPIY）
SELECT 
    'v1spiy_purchases' as info_type,
    id,
    user_id,
    amount_usd,
    payment_status,
    created_at
FROM purchases 
WHERE user_id = 'V1SPIY'
ORDER BY created_at DESC;

-- 7. admin_purchases_viewの現在の状態
SELECT 
    'current_admin_view' as info_type,
    user_id,
    email,
    coinw_uid,
    amount_usd
FROM admin_purchases_view 
WHERE email = 'masataka.tak+22@gmail.com'
LIMIT 1;
