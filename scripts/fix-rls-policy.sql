-- RLSポリシーを修正
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 既存のポリシーがあれば削除
DROP POLICY IF EXISTS "Users can insert their own data" ON users;
DROP POLICY IF EXISTS "Users can read their own data" ON users;
DROP POLICY IF EXISTS "Users can update their own data" ON users;

-- 認証済みユーザーが自分のレコードを挿入できるポリシーを追加
CREATE POLICY "Users can insert their own data" 
ON users FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = id);

-- 認証済みユーザーが自分のレコードを読み取れるポリシーを追加
CREATE POLICY "Users can read their own data" 
ON users FOR SELECT 
TO authenticated 
USING (auth.uid() = id);

-- 認証済みユーザーが自分のレコードを更新できるポリシーを追加
CREATE POLICY "Users can update their own data" 
ON users FOR UPDATE 
TO authenticated 
USING (auth.uid() = id);
