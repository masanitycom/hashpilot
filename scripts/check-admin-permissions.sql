-- 管理者権限の詳細確認

-- 1. adminsテーブルの内容確認
SELECT 
    'Admins Table Check' as check_type,
    email,
    is_active,
    created_at
FROM admins
ORDER BY created_at;

-- 2. auth.usersテーブルでbasarasystems@gmail.comを確認
SELECT 
    'Auth Users Check' as check_type,
    id,
    email,
    email_confirmed_at,
    created_at
FROM auth.users
WHERE email = 'basarasystems@gmail.com';

-- 3. 現在のis_admin関数の定義確認（詳細）
SELECT 
    'Function Definition Check' as check_type,
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    pg_get_function_result(p.oid) as return_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'is_admin'
AND n.nspname = 'public';

-- 4. 関数のパラメータ詳細確認（修正版）
SELECT 
    'Function Parameters Detail' as check_type,
    r.routine_name,
    r.specific_name,
    p.parameter_name,
    p.data_type,
    p.ordinal_position
FROM information_schema.routines r
LEFT JOIN information_schema.parameters p ON r.specific_name = p.specific_name
WHERE r.routine_schema = 'public'
AND r.routine_name = 'is_admin'
ORDER BY r.specific_name, p.ordinal_position;

-- 5. UUIDを使った関数テスト（2パラメータ版を明示的に呼び出し）
DO $$
DECLARE
    user_uuid uuid;
    admin_result boolean;
BEGIN
    -- basarasystems@gmail.comのUUIDを取得
    SELECT id INTO user_uuid 
    FROM auth.users 
    WHERE email = 'basarasystems@gmail.com';
    
    IF user_uuid IS NOT NULL THEN
        -- 2パラメータ版の関数を明示的に呼び出し
        SELECT is_admin('basarasystems@gmail.com', user_uuid) INTO admin_result;
        RAISE NOTICE 'basarasystems@gmail.com Admin Test Result: %', admin_result;
    ELSE
        RAISE NOTICE 'User UUID not found for basarasystems@gmail.com';
    END IF;
    
    -- masataka.tak@gmail.comもテスト
    SELECT id INTO user_uuid 
    FROM auth.users 
    WHERE email = 'masataka.tak@gmail.com';
    
    IF user_uuid IS NOT NULL THEN
        SELECT is_admin('masataka.tak@gmail.com', user_uuid) INTO admin_result;
        RAISE NOTICE 'masataka.tak@gmail.com Admin Test Result: %', admin_result;
    ELSE
        RAISE NOTICE 'User UUID not found for masataka.tak@gmail.com';
    END IF;
END $$;
