-- RLS無効化後、シンプルなRLSを再設定

-- RLSを再度有効化
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;

-- 非常にシンプルなポリシー（認証済みユーザーは全てアクセス可能）
CREATE POLICY "simple_users_policy" 
ON users FOR ALL 
TO authenticated 
USING (true)
WITH CHECK (true);

CREATE POLICY "simple_purchases_policy" 
ON purchases FOR ALL 
TO authenticated 
USING (true)
WITH CHECK (true);

CREATE POLICY "simple_admins_policy" 
ON admins FOR ALL 
TO authenticated 
USING (true)
WITH CHECK (true);

-- ポリシー確認
SELECT 'New simple policies:' as info;
SELECT tablename, policyname, cmd 
FROM pg_policies 
WHERE tablename IN ('users', 'purchases', 'admins')
ORDER BY tablename, policyname;

-- テスト用クエリ
SELECT 'Test after simple RLS:' as test;
