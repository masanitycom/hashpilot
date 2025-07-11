-- test@hashpilot.com, hashpilot.admin@gmail.com, admin@hashpilot.com を管理者から削除

-- ============================================
-- 1. 削除前の確認
-- ============================================
SELECT 
    email,
    role,
    is_active,
    created_at
FROM admins
WHERE email IN (
    'test@hashpilot.com',
    'hashpilot.admin@gmail.com', 
    'admin@hashpilot.com'
);

-- ============================================
-- 2. adminsテーブルから削除
-- ============================================
DELETE FROM admins
WHERE email IN (
    'test@hashpilot.com',
    'hashpilot.admin@gmail.com',
    'admin@hashpilot.com'
);

-- ============================================
-- 3. 削除確認
-- ============================================
-- 削除されたことを確認
SELECT 
    email,
    role,
    is_active
FROM admins
WHERE email IN (
    'test@hashpilot.com',
    'hashpilot.admin@gmail.com',
    'admin@hashpilot.com'
);

-- ============================================
-- 4. 残っている管理者の確認
-- ============================================
SELECT 
    email,
    role,
    is_active,
    created_at
FROM admins
WHERE is_active = true
ORDER BY created_at;

-- 結果：
-- basarasystems@gmail.com (admin)
-- masataka.tak@gmail.com (super_admin)
-- support@dshsupport.biz (admin)