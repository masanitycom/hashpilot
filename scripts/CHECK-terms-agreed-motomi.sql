-- ========================================
-- motomi0101usp@gmail.com / motomi0101usp+2@gmail.com の
-- 利用規約同意状態を確認
-- ========================================

-- 1) 該当ユーザーの terms_agreed_at とid (auth uid)
SELECT
  user_id,
  email,
  id AS auth_uid,
  terms_agreed_at,
  created_at
FROM users
WHERE email IN ('motomi0101usp@gmail.com', 'motomi0101usp+2@gmail.com')
ORDER BY email;

-- 2) usersテーブルのUPDATE関連RLSポリシー一覧
SELECT
  schemaname,
  tablename,
  policyname,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'users'
  AND cmd IN ('UPDATE', 'ALL')
ORDER BY policyname;

-- 3) terms_agreed_at カラムの定義確認
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'terms_agreed_at';
