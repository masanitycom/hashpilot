-- usersテーブルのRLSポリシーを緊急修正

-- 既存のポリシーを削除
DROP POLICY IF EXISTS "Users can access their own data" ON users;
DROP POLICY IF EXISTS "Users can insert their own data" ON users;
DROP POLICY IF EXISTS "Users can read their own data" ON users;
DROP POLICY IF EXISTS "Users can update their own data" ON users;
DROP POLICY IF EXISTS "Users can delete their own data" ON users;
DROP POLICY IF EXISTS "Enable insert for authenticated users during signup" ON users;

-- RLSを有効化
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- シンプルで確実なポリシーを作成
CREATE POLICY "Allow authenticated users to read their own data" 
ON users FOR SELECT 
TO authenticated 
USING (auth.uid() = id);

CREATE POLICY "Allow authenticated users to insert their own data" 
ON users FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = id);

CREATE POLICY "Allow authenticated users to update their own data" 
ON users FOR UPDATE 
TO authenticated 
USING (auth.uid() = id);

-- 管理者は全てのユーザーデータにアクセス可能
CREATE POLICY "Allow admins to access all user data" 
ON users FOR ALL 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM admins a 
        WHERE a.email = (SELECT email FROM auth.users WHERE id = auth.uid())
        AND a.is_active = TRUE
    )
);

-- purchasesテーブルのポリシーも再確認・修正
DROP POLICY IF EXISTS "Allow authenticated users to insert purchases" ON purchases;
DROP POLICY IF EXISTS "Allow authenticated users to read their purchases" ON purchases;
DROP POLICY IF EXISTS "Allow authenticated users to update their purchases" ON purchases;
DROP POLICY IF EXISTS "Allow admins full access to purchases" ON purchases;

-- purchasesテーブルのシンプルなポリシー
CREATE POLICY "Allow authenticated users to insert purchases" 
ON purchases FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY "Allow authenticated users to read their purchases" 
ON purchases FOR SELECT 
TO authenticated 
USING (
    user_id = (
        SELECT user_id FROM users WHERE id = auth.uid()
    )
);

CREATE POLICY "Allow authenticated users to update their purchases" 
ON purchases FOR UPDATE 
TO authenticated 
USING (
    user_id = (
        SELECT user_id FROM users WHERE id = auth.uid()
    )
);

CREATE POLICY "Allow admins full access to purchases" 
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
SELECT 'Users table policies:' as info;
SELECT tablename, policyname, cmd, permissive 
FROM pg_policies 
WHERE tablename = 'users'
ORDER BY policyname;

SELECT 'Purchases table policies:' as info;
SELECT tablename, policyname, cmd, permissive 
FROM pg_policies 
WHERE tablename = 'purchases'
ORDER BY policyname;

-- テスト用クエリ（現在のユーザーがusersテーブルにアクセスできるかテスト）
SELECT 'Test: Can access users table' as test;
