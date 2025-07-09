-- Supabase認証設定の確認（修正版）
SELECT 
  'auth.users テーブル確認' as check_type,
  COUNT(*) as user_count
FROM auth.users;

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

-- 関数の確認
SELECT 
  '関数確認' as check_type,
  routine_name,
  routine_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN ('handle_new_user', 'is_admin');

-- usersテーブルの構造確認
SELECT 
  'usersテーブル構造' as check_type,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'users'
ORDER BY ordinal_position;
