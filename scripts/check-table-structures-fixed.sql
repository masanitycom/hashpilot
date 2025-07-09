-- 詳細なテーブル構造確認（型エラー修正版）

-- 1. auth.usersテーブルの構造
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'auth' AND table_name = 'users'
ORDER BY ordinal_position;

-- 2. public.usersテーブルの構造
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' AND table_name = 'users'
ORDER BY ordinal_position;

-- 3. purchasesテーブルの構造
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' AND table_name = 'purchases'
ORDER BY ordinal_position;

-- 4. 実際のデータ型確認（auth.users）
SELECT 
    'auth.users' as source_table,
    id::text as id_value,
    pg_typeof(id) as id_type,
    email,
    pg_typeof(email) as email_type,
    raw_user_meta_data->>'coinw_uid' as coinw_uid_from_metadata
FROM auth.users 
LIMIT 3;

-- 5. 実際のデータ型確認（public.users）
SELECT 
    'public.users' as source_table,
    id::text as id_value,
    pg_typeof(id) as id_type,
    user_id,
    pg_typeof(user_id) as user_id_type,
    email,
    coinw_uid,
    pg_typeof(coinw_uid) as coinw_uid_type
FROM users 
LIMIT 3;

-- 6. V1SPIYユーザーの詳細情報（auth.users）
SELECT 
    'V1SPIY_auth' as check_type,
    id::text as user_id,
    email,
    raw_user_meta_data,
    raw_user_meta_data->>'coinw_uid' as coinw_uid_metadata
FROM auth.users 
WHERE email = 'masataka.tak+22@gmail.com';

-- 7. V1SPIYユーザーの詳細情報（public.users）
SELECT 
    'V1SPIY_public' as check_type,
    id::text as user_id,
    user_id as display_user_id,
    email,
    coinw_uid
FROM users 
WHERE email = 'masataka.tak+22@gmail.com';

-- 8. テーブル間の関係確認
SELECT 
    'relationship_check' as check_type,
    au.id::text as auth_id,
    au.email as auth_email,
    u.id::text as public_id,
    u.user_id as public_user_id,
    u.email as public_email,
    u.coinw_uid as public_coinw_uid,
    au.raw_user_meta_data->>'coinw_uid' as auth_coinw_uid,
    CASE 
        WHEN au.id = u.id THEN 'ID一致'
        ELSE 'ID不一致'
    END as id_match_status
FROM auth.users au
LEFT JOIN users u ON au.id = u.id
WHERE au.email = 'masataka.tak+22@gmail.com';

-- 9. 全ユーザーのCoinW UID状況
SELECT 
    'coinw_uid_summary' as check_type,
    COUNT(*) as total_users,
    COUNT(coinw_uid) as users_with_coinw_uid,
    COUNT(*) - COUNT(coinw_uid) as users_without_coinw_uid
FROM users;
