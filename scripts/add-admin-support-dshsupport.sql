-- support@dshsupport.biz を管理者として追加するスクリプト
-- 
-- 重要: このスクリプトを実行する前に、Supabase Authenticationで
-- ユーザーアカウントを作成する必要があります。
--
-- 手順:
-- 1. Supabase Dashboard → Authentication → Users
-- 2. "Add user" → "Send invitation" をクリック
-- 3. Email: support@dshsupport.biz
-- 4. Password: mU4W9KvH
-- 5. ユーザーを作成
-- 6. その後、このSQLを実行

-- ============================================
-- 1. まずユーザーが存在するか確認
-- ============================================
SELECT 
    id,
    user_id,
    email,
    is_admin,
    created_at
FROM users
WHERE email = 'support@dshsupport.biz';

-- ユーザーが見つからない場合は、上記の手順でAuthenticationにユーザーを作成してください

-- ============================================
-- 2. usersテーブルのis_adminフラグを更新
-- ============================================
UPDATE users
SET is_admin = true
WHERE email = 'support@dshsupport.biz';

-- ============================================
-- 3. adminsテーブルに追加（テーブルが存在する場合）
-- ============================================
-- adminsテーブルの存在確認
DO $$
BEGIN
    IF EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'admins'
    ) THEN
        -- adminsテーブルが存在する場合のみ実行
        INSERT INTO admins (user_id, email, role, is_active, created_at)
        SELECT 
            id,
            email,
            'admin',
            true,
            NOW()
        FROM users
        WHERE email = 'support@dshsupport.biz'
        ON CONFLICT (email) DO UPDATE
        SET 
            is_active = true,
            role = 'admin',
            updated_at = NOW();
    END IF;
END $$;

-- ============================================
-- 4. 設定確認
-- ============================================
SELECT 
    u.id,
    u.user_id,
    u.email,
    u.is_admin as users_is_admin,
    u.created_at
FROM users u
WHERE u.email = 'support@dshsupport.biz';

-- ============================================
-- 5. 全管理者の確認
-- ============================================
SELECT 
    email,
    is_admin,
    created_at
FROM users
WHERE is_admin = true
ORDER BY created_at;