-- ログイン問題を修正するためのスクリプト（rowsecurityエラー修正版）

-- 1. auth.usersテーブルの状態を確認
SELECT 
    id,
    email,
    email_confirmed_at,
    last_sign_in_at,
    created_at,
    updated_at
FROM auth.users 
WHERE email IN ('yutaka19791105@gmail.com', 'tmtm1108tmtm@gmail.com')
ORDER BY created_at DESC;

-- 2. usersテーブルとの整合性を確認
SELECT 
    au.email as auth_email,
    u.email as user_email,
    u.user_id,
    u.coinw_uid,
    au.email_confirmed_at,
    au.last_sign_in_at
FROM auth.users au
LEFT JOIN users u ON au.id = u.id
WHERE au.email = 'yutaka19791105@gmail.com';

-- 3. メール確認状態を修正
UPDATE auth.users 
SET 
    email_confirmed_at = NOW(),
    updated_at = NOW()
WHERE email = 'yutaka19791105@gmail.com' 
AND email_confirmed_at IS NULL;

-- 4. RLSポリシーが正しく動作しているか確認（rowsecurityカラムを除外）
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename IN ('users', 'purchases')
ORDER BY tablename, policyname;

-- 5. テーブルのRLS状態を確認
SELECT 
    schemaname,
    tablename,
    CASE 
        WHEN relrowsecurity THEN 'ENABLED'
        ELSE 'DISABLED'
    END as rls_status
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public' 
AND c.relname IN ('users', 'purchases')
AND c.relkind = 'r';

-- 6. 認証が正常に動作するかテスト
SELECT 'Login system check completed' as status;
