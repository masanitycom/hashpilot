-- 全テーブル構造の詳細確認

-- 1. usersテーブルの構造
SELECT 
    'users_table_structure' as check_type,
    column_name, 
    data_type, 
    character_maximum_length,
    column_default,
    is_nullable,
    ordinal_position
FROM information_schema.columns 
WHERE table_name = 'users' 
ORDER BY ordinal_position;

-- 2. purchasesテーブルの構造
SELECT 
    'purchases_table_structure' as check_type,
    column_name, 
    data_type, 
    character_maximum_length,
    column_default,
    is_nullable,
    ordinal_position
FROM information_schema.columns 
WHERE table_name = 'purchases' 
ORDER BY ordinal_position;

-- 3. adminsテーブルの構造
SELECT 
    'admins_table_structure' as check_type,
    column_name, 
    data_type, 
    character_maximum_length,
    column_default,
    is_nullable,
    ordinal_position
FROM information_schema.columns 
WHERE table_name = 'admins' 
ORDER BY ordinal_position;

-- 4. system_settingsテーブルの構造
SELECT 
    'system_settings_table_structure' as check_type,
    column_name, 
    data_type, 
    character_maximum_length,
    column_default,
    is_nullable,
    ordinal_position
FROM information_schema.columns 
WHERE table_name = 'system_settings' 
ORDER BY ordinal_position;

-- 5. 現在の関数一覧
SELECT 
    'existing_functions' as check_type,
    proname as function_name,
    pg_get_function_arguments(oid) as arguments,
    pg_get_function_result(oid) as return_type
FROM pg_proc 
WHERE proname LIKE '%referral%' OR proname LIKE '%admin%'
ORDER BY proname;

-- 6. サンプルデータ確認
SELECT 
    'users_sample_data' as check_type,
    user_id,
    email,
    referrer_user_id,
    coinw_uid,
    created_at
FROM users 
LIMIT 5;

SELECT 
    'purchases_sample_data' as check_type,
    id,
    user_id,
    amount_usd,
    payment_status,
    admin_approved
FROM purchases 
LIMIT 5;
