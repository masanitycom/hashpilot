-- 管理者アカウントの確認スクリプト

-- 1. adminsテーブルの内容を確認
SELECT 
    id,
    user_id,
    email,
    role,
    is_active,
    created_at
FROM admins
ORDER BY created_at;

-- 2. is_admin関数の定義を確認
SELECT 
    routine_name,
    routine_definition
FROM information_schema.routines
WHERE routine_name = 'is_admin';

-- 3. usersテーブルでis_admin=trueのユーザーを確認
SELECT 
    id,
    user_id,
    email,
    is_admin,
    created_at
FROM users
WHERE is_admin = true
ORDER BY created_at;

-- 4. basarasystems@gmail.comの現在のステータスを確認
SELECT 
    u.id,
    u.user_id,
    u.email,
    u.is_admin as users_is_admin,
    a.id as admin_id,
    a.role as admin_role,
    a.is_active as admin_is_active
FROM users u
LEFT JOIN admins a ON u.email = a.email
WHERE u.email = 'basarasystems@gmail.com';