-- メール送信状況を確認するクエリ
SELECT 
  email,
  email_confirmed_at,
  created_at,
  confirmation_sent_at,
  email_change_sent_at,
  recovery_sent_at
FROM auth.users 
WHERE email = 'masataka.tak@gmail.com'
ORDER BY created_at DESC;

-- 全体のメール確認状況
SELECT 
  COUNT(*) as total_users,
  COUNT(email_confirmed_at) as confirmed_users,
  COUNT(*) - COUNT(email_confirmed_at) as unconfirmed_users
FROM auth.users;

-- 最近の登録ユーザー
SELECT 
  email,
  created_at,
  email_confirmed_at IS NULL as needs_confirmation,
  EXTRACT(EPOCH FROM (NOW() - created_at))/3600 as hours_since_signup
FROM auth.users 
ORDER BY created_at DESC 
LIMIT 10;
