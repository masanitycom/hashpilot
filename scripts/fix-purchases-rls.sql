-- purchasesテーブルのRLSポリシーを修正

-- 既存のポリシーを削除
DROP POLICY IF EXISTS "Users can access their own purchases" ON purchases;
DROP POLICY IF EXISTS "Users can insert their own purchases" ON purchases;
DROP POLICY IF EXISTS "Users can update their own purchases" ON purchases;
DROP POLICY IF EXISTS "Users can read their own purchases" ON purchases;

-- RLSを有効化
ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;

-- ユーザーが自分の購入データを挿入できるポリシー
CREATE POLICY "Users can insert their own purchases" 
ON purchases FOR INSERT 
TO authenticated 
WITH CHECK (
    user_id = (
        SELECT user_id FROM users WHERE id = auth.uid()
    )
);

-- ユーザーが自分の購入データを読み取れるポリシー
CREATE POLICY "Users can read their own purchases" 
ON purchases FOR SELECT 
TO authenticated 
USING (
    user_id = (
        SELECT user_id FROM users WHERE id = auth.uid()
    )
);

-- ユーザーが自分の購入データを更新できるポリシー
CREATE POLICY "Users can update their own purchases" 
ON purchases FOR UPDATE 
TO authenticated 
USING (
    user_id = (
        SELECT user_id FROM users WHERE id = auth.uid()
    )
);

-- 管理者が全ての購入データにアクセスできるポリシー
CREATE POLICY "Admins can access all purchases" 
ON purchases FOR ALL 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM admins a 
        JOIN users u ON u.email = a.email
        WHERE u.id = auth.uid() AND a.is_active = TRUE
    )
);

-- purchase_admin_viewのRLSも設定
ALTER TABLE IF EXISTS purchase_admin_view ENABLE ROW LEVEL SECURITY;

-- 管理者のみがビューにアクセス可能
CREATE POLICY IF NOT EXISTS "Admins can access purchase admin view" 
ON purchase_admin_view FOR SELECT 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM admins a 
        JOIN users u ON u.email = a.email
        WHERE u.id = auth.uid() AND a.is_active = TRUE
    )
);

-- 現在のポリシー状況を確認
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('purchases', 'users', 'admins')
ORDER BY tablename, policyname;
