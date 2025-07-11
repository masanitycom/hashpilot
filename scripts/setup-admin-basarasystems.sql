-- basarasystems@gmail.com を管理者として設定

-- 1. adminsテーブルに追加（既に存在する場合は更新）
INSERT INTO admins (email, role, is_active)
VALUES ('basarasystems@gmail.com', 'super_admin', TRUE)
ON CONFLICT (email) 
DO UPDATE SET 
    role = 'super_admin',
    is_active = TRUE;

-- 2. usersテーブルのis_adminフラグを設定
UPDATE users 
SET is_admin = TRUE
WHERE email = 'basarasystems@gmail.com';

-- 3. 設定を確認
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

-- 4. 他の管理者アカウントを確認
SELECT 
    u.email,
    u.is_admin as users_is_admin,
    a.role as admin_role,
    a.is_active as admin_is_active
FROM users u
LEFT JOIN admins a ON u.email = a.email
WHERE u.is_admin = TRUE OR a.id IS NOT NULL
ORDER BY u.created_at;