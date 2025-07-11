-- support@dshsupport.bizの管理者権限を確認

-- 1. adminsテーブルの確認
SELECT 
    email,
    role,
    is_active,
    created_at,
    user_id
FROM admins
WHERE email = 'support@dshsupport.biz';

-- 2. usersテーブルの確認
SELECT 
    id,
    user_id,
    email,
    created_at
FROM users
WHERE email = 'support@dshsupport.biz';

-- 3. 全てのアクティブな管理者を確認
SELECT 
    email,
    role,
    is_active,
    created_at
FROM admins
WHERE is_active = true
ORDER BY created_at;

-- 4. もしadminsテーブルに存在しない場合、追加する
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

-- 5. 追加後の確認
SELECT 
    email,
    role,
    is_active,
    created_at
FROM admins
WHERE email = 'support@dshsupport.biz';