-- 緊急修正：purchasesテーブルのRLSポリシーを即座に修正

-- 一時的にRLSを無効化してテスト
ALTER TABLE purchases DISABLE ROW LEVEL SECURITY;

-- 既存のポリシーをすべて削除
DROP POLICY IF EXISTS "Users can access their own purchases" ON purchases;
DROP POLICY IF EXISTS "Users can insert their own purchases" ON purchases;
DROP POLICY IF EXISTS "Users can update their own purchases" ON purchases;
DROP POLICY IF EXISTS "Users can read their own purchases" ON purchases;
DROP POLICY IF EXISTS "Admins can access all purchases" ON purchases;

-- RLSを再度有効化
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;

-- シンプルなポリシーから開始
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

-- 管理者用ポリシー
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
SELECT tablename, policyname, cmd, permissive 
FROM pg_policies 
WHERE tablename = 'purchases'
ORDER BY policyname;

-- テスト用クエリ
SELECT 'Test query - current user can access users table:' as test;
SELECT COUNT(*) as user_count FROM users WHERE id = auth.uid();
