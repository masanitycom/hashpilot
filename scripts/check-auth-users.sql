-- 認証ユーザーの状況を確認
SELECT 
  id,
  email,
  email_confirmed_at IS NOT NULL as email_confirmed,
  created_at,
  last_sign_in_at,
  CASE 
    WHEN email_confirmed_at IS NULL THEN 'メール未確認'
    WHEN last_sign_in_at IS NULL THEN 'ログイン未実行'
    ELSE '正常'
  END as status
FROM auth.users 
ORDER BY created_at DESC 
LIMIT 10;

-- 管理者アカウントの確認
SELECT 
  a.email as admin_email,
  a.role,
  a.is_active,
  au.email_confirmed_at IS NOT NULL as email_confirmed,
  au.last_sign_in_at
FROM admins a
LEFT JOIN auth.users au ON a.email = au.email
ORDER BY a.created_at DESC;

-- 特定のメールアドレスの詳細確認
SELECT 
  'Auth user details:' as info,
  id,
  email,
  email_confirmed_at,
  created_at,
  last_sign_in_at
FROM auth.users 
WHERE email = 'masataka.tak@gmail.com';
