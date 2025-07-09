-- 現在のユーザー状況を確認
SELECT 
  au.id,
  au.email,
  au.email_confirmed_at,
  au.created_at as auth_created_at,
  u.user_id,
  u.email as users_email,
  u.created_at as users_created_at,
  CASE 
    WHEN u.id IS NULL THEN 'usersテーブルにレコードなし'
    WHEN au.email_confirmed_at IS NULL THEN 'メール未確認'
    ELSE '正常'
  END as status
FROM auth.users au
LEFT JOIN users u ON au.id = u.id
WHERE au.email = 'masataka.tak@gmail.com'
ORDER BY au.created_at DESC;

-- トリガーの状態確認
SELECT 
  trigger_name,
  event_manipulation,
  action_statement,
  action_timing
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- 最近作成されたユーザーの状況
SELECT 
  au.email,
  au.email_confirmed_at IS NOT NULL as email_confirmed,
  u.user_id IS NOT NULL as has_user_record,
  au.created_at
FROM auth.users au
LEFT JOIN users u ON au.id = u.id
ORDER BY au.created_at DESC
LIMIT 10;
