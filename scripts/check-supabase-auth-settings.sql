-- Supabase認証設定の確認
SELECT 
  'auth.users テーブル確認' as check_type,
  COUNT(*) as user_count
FROM auth.users;

-- メール設定の確認
SELECT 
  'auth設定確認' as check_type,
  setting_name,
  setting_value
FROM auth.config
WHERE setting_name IN ('SITE_URL', 'MAILER_AUTOCONFIRM', 'DISABLE_SIGNUP');

-- RLSポリシーの確認
SELECT 
  'RLSポリシー確認' as check_type,
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('users', 'purchases');

-- トリガーの確認
SELECT 
  'トリガー確認' as check_type,
  trigger_name,
  event_manipulation,
  action_statement
FROM information_schema.triggers 
WHERE trigger_schema = 'public';

-- 最近のauth.usersの状況確認
SELECT 
  'auth.users最新状況' as check_type,
  id,
  email,
  email_confirmed_at,
  created_at,
  raw_user_meta_data
FROM auth.users 
ORDER BY created_at DESC 
LIMIT 5;
