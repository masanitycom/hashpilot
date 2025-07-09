-- V1SPIYユーザーのCoinW UID問題を詳細調査

-- 1. V1SPIYユーザーのauth.usersデータ
SELECT 
    'auth_users_v1spiy' as check_type,
    id::text as auth_id,
    email,
    raw_user_meta_data,
    raw_user_meta_data->>'coinw_uid' as coinw_uid_from_metadata,
    created_at
FROM auth.users 
WHERE email = 'masataka.tak+22@gmail.com';

-- 2. V1SPIYユーザーのpublic.usersデータ
SELECT 
    'public_users_v1spiy' as check_type,
    id::text as public_id,
    user_id,
    email,
    coinw_uid,
    created_at
FROM users 
WHERE email = 'masataka.tak+22@gmail.com' OR user_id = 'V1SPIY';

-- 3. IDの関連性確認
SELECT 
    'id_relationship' as check_type,
    au.id::text as auth_id,
    u.id::text as public_id,
    au.email as auth_email,
    u.email as public_email,
    u.user_id,
    u.coinw_uid as current_coinw_uid,
    au.raw_user_meta_data->>'coinw_uid' as metadata_coinw_uid
FROM auth.users au
FULL OUTER JOIN users u ON au.id = u.id
WHERE au.email = 'masataka.tak+22@gmail.com' 
   OR u.email = 'masataka.tak+22@gmail.com'
   OR u.user_id = 'V1SPIY';

-- 4. admin_purchases_viewの結合確認
SELECT 
    'admin_view_join_debug' as check_type,
    p.user_id,
    p.amount_usd,
    u.email,
    u.coinw_uid,
    u.id::text as users_table_id
FROM purchases p
LEFT JOIN users u ON p.user_id = u.user_id
WHERE p.user_id = 'V1SPIY';

-- 5. 手動でCoinW UIDを設定（テスト用）
UPDATE users 
SET coinw_uid = 'TEST_COINW_UID_V1SPIY',
    updated_at = NOW()
WHERE user_id = 'V1SPIY' OR email = 'masataka.tak+22@gmail.com';

-- 6. 更新後の確認
SELECT 
    'after_manual_update' as check_type,
    user_id,
    email,
    coinw_uid,
    updated_at
FROM users 
WHERE user_id = 'V1SPIY' OR email = 'masataka.tak+22@gmail.com';

-- 7. admin_purchases_viewでの最終確認
SELECT 
    'final_admin_view_check' as check_type,
    user_id,
    email,
    coinw_uid,
    amount_usd
FROM admin_purchases_view 
WHERE user_id = 'V1SPIY';
