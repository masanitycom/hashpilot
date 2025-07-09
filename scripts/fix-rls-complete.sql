-- RLSポリシーを完全に修正（より確実な方法）

-- 一時的にRLSを無効化してテスト
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE purchases DISABLE ROW LEVEL SECURITY;

-- 既存のポリシーをすべて削除
DROP POLICY IF EXISTS "Allow authenticated users to read their own data" ON users;
DROP POLICY IF EXISTS "Allow authenticated users to insert their own data" ON users;
DROP POLICY IF EXISTS "Allow authenticated users to update their own data" ON users;
DROP POLICY IF EXISTS "Allow admins to access all user data" ON users;
DROP POLICY IF EXISTS "Users can access their own data" ON users;
DROP POLICY IF EXISTS "Users can insert their own data" ON users;
DROP POLICY IF EXISTS "Users can read their own data" ON users;
DROP POLICY IF EXISTS "Users can update their own data" ON users;
DROP POLICY IF EXISTS "Users can delete their own data" ON users;
DROP POLICY IF EXISTS "Enable insert for authenticated users during signup" ON users;

DROP POLICY IF EXISTS "Allow authenticated users to insert purchases" ON purchases;
DROP POLICY IF EXISTS "Allow authenticated users to read their purchases" ON purchases;
DROP POLICY IF EXISTS "Allow authenticated users to update their purchases" ON purchases;
DROP POLICY IF EXISTS "Allow admins full access to purchases" ON purchases;
DROP POLICY IF EXISTS "Users can insert their own purchases" ON purchases;
DROP POLICY IF EXISTS "Users can read their own purchases" ON purchases;
DROP POLICY IF EXISTS "Users can update their own purchases" ON purchases;
DROP POLICY IF EXISTS "Admins can access all purchases" ON purchases;

-- RLSを再度有効化
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;

-- usersテーブル用の非常にシンプルなポリシー
CREATE POLICY "users_policy_select" 
ON users FOR SELECT 
TO authenticated 
USING (auth.uid() = id);

CREATE POLICY "users_policy_insert" 
ON users FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = id);

CREATE POLICY "users_policy_update" 
ON users FOR UPDATE 
TO authenticated 
USING (auth.uid() = id);

-- purchasesテーブル用のシンプルなポリシー
CREATE POLICY "purchases_policy_insert" 
ON purchases FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY "purchases_policy_select" 
ON purchases FOR SELECT 
TO authenticated 
USING (
    user_id = (
        SELECT user_id FROM users WHERE id = auth.uid()
    )
);

CREATE POLICY "purchases_policy_update" 
ON purchases FOR UPDATE 
TO authenticated 
USING (
    user_id = (
        SELECT user_id FROM users WHERE id = auth.uid()
    )
);

-- 管理者用ポリシー（users）
CREATE POLICY "users_admin_policy" 
ON users FOR ALL 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM admins a 
        WHERE a.email = (SELECT email FROM auth.users WHERE id = auth.uid())
        AND a.is_active = TRUE
    )
);

-- 管理者用ポリシー（purchases）
CREATE POLICY "purchases_admin_policy" 
ON purchases FOR ALL 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM admins a 
        WHERE a.email = (SELECT email FROM auth.users WHERE id = auth.uid())
        AND a.is_active = TRUE
    )
);

-- 現在のポリシー状況を確認
SELECT 'Users policies:' as table_name, policyname, cmd 
FROM pg_policies 
WHERE tablename = 'users'
UNION ALL
SELECT 'Purchases policies:' as table_name, policyname, cmd 
FROM pg_policies 
WHERE tablename = 'purchases'
ORDER BY table_name, policyname;

-- テスト用クエリ
SELECT 'Test completed' as status;
