-- 7DCFB7 ログイン問題調査

-- 1. usersテーブル確認
SELECT 
    user_id, 
    email, 
    id,
    is_active,
    created_at
FROM users 
WHERE user_id = '7DCFB7';

-- 2. auth.usersテーブル確認（詳細）
SELECT 
    id, 
    email,
    email_confirmed_at,
    last_sign_in_at,
    created_at,
    updated_at,
    banned_until,
    is_sso_user,
    deleted_at
FROM auth.users 
WHERE id = 'c45f263b-a445-47c5-bd22-249eb52371d7';

-- 3. メールアドレスの重複チェック
SELECT 
    id, 
    email 
FROM auth.users 
WHERE email = 'miekohannsei@gmail.com';

-- 4. 旧メールアドレスがまだ残っていないか確認
SELECT 
    id, 
    email 
FROM auth.users 
WHERE email = 'muma.mieko@gmail.com';
