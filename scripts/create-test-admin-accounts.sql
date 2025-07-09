-- テスト用管理者アカウントを作成

-- 1. 認証テーブルに直接挿入（Supabaseの場合）
-- 注意: 実際の環境では管理画面から作成することを推奨

-- テスト用管理者をadminsテーブルに追加
INSERT INTO admins (user_id, email, created_at) VALUES
('test-admin-1', 'admin@hashpilot.com', NOW()),
('test-admin-2', 'test@hashpilot.com', NOW()),
('test-admin-3', 'hashpilot.admin@gmail.com', NOW())
ON CONFLICT (email) DO NOTHING;

-- 既存の管理者も確認
SELECT email, created_at FROM admins ORDER BY created_at;

-- 認証ユーザー情報を確認
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
ORDER BY created_at;
