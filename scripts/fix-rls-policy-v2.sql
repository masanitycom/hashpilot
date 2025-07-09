-- 既存のポリシーを削除
DROP POLICY IF EXISTS "Users can insert their own data" ON users;
DROP POLICY IF EXISTS "Users can read their own data" ON users;
DROP POLICY IF EXISTS "Users can update their own data" ON users;

-- より柔軟な挿入ポリシー（サインアップ時用）
CREATE POLICY "Enable insert for authenticated users during signup" 
ON users FOR INSERT 
TO authenticated 
WITH CHECK (true);

-- 自分のデータのみ読み取り可能
CREATE POLICY "Users can read their own data" 
ON users FOR SELECT 
TO authenticated 
USING (auth.uid() = id);

-- 自分のデータのみ更新可能
CREATE POLICY "Users can update their own data" 
ON users FOR UPDATE 
TO authenticated 
USING (auth.uid() = id);

-- 自分のデータのみ削除可能
CREATE POLICY "Users can delete their own data" 
ON users FOR DELETE 
TO authenticated 
USING (auth.uid() = id);
