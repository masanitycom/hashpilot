-- メール認証設定の確認用クエリ
-- これらの設定はSupabaseダッシュボードで行う必要があります

-- 1. Authentication > Settings で以下を確認:
-- - Enable email confirmations: ON
-- - Secure email change: ON (推奨)
-- - Enable phone confirmations: OFF (メール認証のみの場合)

-- 2. Authentication > Email Templates で以下をカスタマイズ:
-- - Confirm signup: 登録確認メール
-- - Magic Link: マジックリンクメール
-- - Change Email Address: メールアドレス変更確認
-- - Reset Password: パスワードリセット

-- 3. 現在の認証設定を確認するクエリ
SELECT 
  email_confirmed_at,
  email,
  created_at,
  last_sign_in_at
FROM auth.users 
ORDER BY created_at DESC 
LIMIT 10;

-- 4. 未確認のユーザーを確認
SELECT 
  email,
  created_at,
  email_confirmed_at IS NULL as is_unconfirmed
FROM auth.users 
WHERE email_confirmed_at IS NULL
ORDER BY created_at DESC;
