-- usersテーブルの構造を確認するスクリプト

-- 1. usersテーブルのカラム一覧を確認
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'users'
ORDER BY ordinal_position;

-- 2. usersテーブルのサンプルデータを確認（最初の5件）
SELECT * FROM users LIMIT 5;

-- 3. adminsテーブルが存在するか確認
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'admins'
) as admins_table_exists;

-- 4. adminsテーブルが存在する場合、その構造を確認
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'admins'
ORDER BY ordinal_position;

-- 5. 管理者を特定する方法を確認
-- Option A: adminsテーブルに存在するユーザー
SELECT 
    a.email,
    a.role,
    a.is_active,
    u.email as user_email
FROM admins a
LEFT JOIN users u ON a.email = u.email
WHERE a.is_active = true;

-- Option B: is_admin RPC関数の存在確認
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_name = 'is_admin';