-- 全テーブル構造の完全確認

-- 1. usersテーブルの構造
SELECT 
    'users_table' as table_name,
    column_name, 
    data_type, 
    character_maximum_length,
    column_default,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'users' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. purchasesテーブルの構造
SELECT 
    'purchases_table' as table_name,
    column_name, 
    data_type, 
    character_maximum_length,
    column_default,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'purchases' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 3. adminsテーブルの構造
SELECT 
    'admins_table' as table_name,
    column_name, 
    data_type, 
    character_maximum_length,
    column_default,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'admins' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 4. system_settingsテーブルの構造（もしあれば）
SELECT 
    'system_settings_table' as table_name,
    column_name, 
    data_type, 
    character_maximum_length,
    column_default,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'system_settings' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 5. auth.usersテーブルの構造
SELECT 
    'auth_users_table' as table_name,
    column_name, 
    data_type, 
    character_maximum_length,
    column_default,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'users' 
AND table_schema = 'auth'
ORDER BY ordinal_position;

-- 6. 実際のデータ型確認
SELECT 
    'users_data_types' as check_type,
    pg_typeof(id) as id_type,
    pg_typeof(user_id) as user_id_type,
    pg_typeof(email) as email_type
FROM users 
LIMIT 1;

SELECT 
    'purchases_data_types' as check_type,
    pg_typeof(id) as id_type,
    pg_typeof(user_id) as user_id_type,
    pg_typeof(amount_usd) as amount_type
FROM purchases 
LIMIT 1;

SELECT 
    'auth_users_data_types' as check_type,
    pg_typeof(id) as id_type,
    pg_typeof(email) as email_type
FROM auth.users 
LIMIT 1;

-- 7. 外部キー制約の確認
SELECT
    'foreign_keys' as check_type,
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM 
    information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
AND tc.table_schema = 'public'
AND tc.table_name IN ('users', 'purchases', 'admins');
