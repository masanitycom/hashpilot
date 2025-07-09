-- 詳細なテーブル構造確認

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
    id,
    pg_typeof(id) as id_type,
    email,
    pg_typeof(email) as email_type,
    created_at,
    raw_user_meta_data->>'coinw_uid' as coinw_uid_from_metadata
FROM auth.users 
LIMIT 3;

-- 5. 実際のデータ型確認（public.users）
SELECT 
    id,
    pg_typeof(id) as id_type,
    user_id,
    pg_typeof(user_id) as user_id_type,
    email,
    coinw_uid,
    pg_typeof(coinw_uid) as coinw_uid_type
FROM users 
LIMIT 3;

-- 6. V1SPIYユーザーの詳細情報
SELECT 
    'auth.users' as table_name,
    id,
    email,
    raw_user_meta_data,
    raw_user_meta_data->>'coinw_uid' as coinw_uid_metadata
FROM auth.users 
WHERE email = 'masataka.tak+22@gmail.com'
UNION ALL
SELECT 
    'public.users' as table_name,
    id::text,
    email,
    NULL as raw_user_meta_data,
    coinw_uid as coinw_uid_metadata
FROM users 
WHERE email = 'masataka.tak+22@gmail.com';

-- 7. テーブル間の関係確認
SELECT 
    au.id as auth_id,
    au.email as auth_email,
    u.id as public_id,
    u.user_id as public_user_id,
    u.email as public_email,
    u.coinw_uid as public_coinw_uid,
    au.raw_user_meta_data->>'coinw_uid' as auth_coinw_uid
FROM auth.users au
LEFT JOIN users u ON au.id = u.id
WHERE au.email = 'masataka.tak+22@gmail.com';
