-- 管理者認証のデバッグ用クエリ

-- 1. 管理者テーブルの状況確認
SELECT 'Admins table:' as info;
SELECT 
  id,
  user_id,
  email,
  role,
  is_active,
  created_at
FROM admins
ORDER BY created_at DESC;

-- 2. 特定メールアドレスの認証状況
SELECT 'Auth user for masataka.tak@gmail.com:' as info;
SELECT 
  id,
  email,
  email_confirmed_at IS NOT NULL as email_confirmed,
  created_at,
  last_sign_in_at,
  raw_user_meta_data
FROM auth.users 
WHERE email = 'masataka.tak@gmail.com';

-- 3. 管理者権限チェック関数のテスト
SELECT 'Admin check function test:' as info;
SELECT is_admin('masataka.tak@gmail.com') as is_admin_result;

-- 4. usersテーブルとの関連確認
SELECT 'Users table relation:' as info;
SELECT 
  u.user_id,
  u.email,
  u.has_approved_nft,
  au.email_confirmed_at IS NOT NULL as auth_confirmed
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE au.email = 'masataka.tak@gmail.com';

-- 5. RLSポリシーの状況確認
SELECT 'Current RLS policies:' as info;
SELECT 
  tablename,
  policyname,
  cmd,
  permissive
FROM pg_policies 
WHERE tablename IN ('users', 'purchases', 'admins')
ORDER BY tablename, policyname;
