-- 管理者アカウントの情報を表示
SELECT 
    email,
    is_active,
    created_at,
    CASE 
        WHEN email = 'admin@hashpilot.com' THEN 'admin123'
        WHEN email = 'test@hashpilot.com' THEN 'test123'
        WHEN email = 'hashpilot.admin@gmail.com' THEN 'hashpilot123'
        ELSE 'パスワード不明'
    END as password_hint
FROM admins 
WHERE email IN (
    'admin@hashpilot.com',
    'test@hashpilot.com', 
    'hashpilot.admin@gmail.com'
)
ORDER BY created_at DESC;

-- 実際のauth.usersテーブルも確認
SELECT 
    email,
    created_at,
    email_confirmed_at,
    last_sign_in_at
FROM auth.users 
WHERE email IN (
    'basarasystems@gmail.com',
    'masataka.tak@gmail.com',
    'admin@hashpilot.com',
    'test@hashpilot.com',
    'hashpilot.admin@gmail.com'
)
ORDER BY created_at DESC;
