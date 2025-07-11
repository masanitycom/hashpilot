-- 新しい管理者アカウントを追加するためのSQLスクリプト
-- 使用方法: 'new-admin@example.com' を新しい管理者のメールアドレスに置き換えて実行

-- ============================================
-- 1. まず対象ユーザーが存在するか確認
-- ============================================
SELECT 
    id,
    user_id,
    email,
    is_admin,
    created_at
FROM users
WHERE email = 'new-admin@example.com';

-- ============================================
-- 2. usersテーブルのis_adminフラグを更新
-- ============================================
UPDATE users
SET is_admin = true
WHERE email = 'new-admin@example.com';

-- ============================================
-- 3. adminsテーブルに追加（もし存在する場合）
-- ============================================
-- adminsテーブルが存在する場合のみ実行
INSERT INTO admins (user_id, email, role, is_active, created_at)
SELECT 
    id,
    email,
    'admin', -- 'admin' または 'super_admin'
    true,
    NOW()
FROM users
WHERE email = 'new-admin@example.com'
ON CONFLICT (email) DO UPDATE
SET 
    is_active = true,
    role = 'admin',
    updated_at = NOW();

-- ============================================
-- 4. 設定確認
-- ============================================
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
WHERE u.email = 'new-admin@example.com';

-- ============================================
-- 5. 全管理者の確認
-- ============================================
SELECT 
    u.email,
    u.is_admin,
    a.role,
    a.is_active,
    u.created_at
FROM users u
LEFT JOIN admins a ON u.email = a.email
WHERE u.is_admin = true OR a.id IS NOT NULL
ORDER BY u.created_at;