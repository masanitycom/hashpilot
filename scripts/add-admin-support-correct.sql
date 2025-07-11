-- support@dshsupport.biz を管理者として追加する正しいスクリプト
-- 
-- このスクリプトはis_adminカラムが存在しない場合の対応版です

-- ============================================
-- 1. まずユーザーが存在するか確認
-- ============================================
SELECT 
    id,
    user_id,
    email,
    created_at
FROM users
WHERE email = 'support@dshsupport.biz';

-- ============================================
-- 2. adminsテーブルに追加（これが主要な管理者設定）
-- ============================================
-- adminsテーブルが存在する場合
INSERT INTO admins (email, role, is_active, created_at)
VALUES (
    'support@dshsupport.biz',
    'admin',
    true,
    NOW()
)
ON CONFLICT (email) DO UPDATE
SET 
    is_active = true,
    role = 'admin';

-- ユーザーIDで関連付ける必要がある場合
UPDATE admins a
SET user_id = u.id
FROM users u
WHERE a.email = u.email
AND a.email = 'support@dshsupport.biz';

-- ============================================
-- 3. 設定確認
-- ============================================
-- 管理者として設定されたか確認
SELECT 
    a.email,
    a.role,
    a.is_active,
    u.id as user_id,
    u.email as user_email
FROM admins a
LEFT JOIN users u ON a.email = u.email
WHERE a.email = 'support@dshsupport.biz';

-- ============================================
-- 4. 全管理者の確認
-- ============================================
SELECT 
    email,
    role,
    is_active,
    created_at
FROM admins
WHERE is_active = true
ORDER BY created_at;