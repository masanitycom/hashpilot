-- purchasesテーブルのRLSポリシーを修正（adminsテーブル作成後）

-- 既存のポリシーを削除
DROP POLICY IF EXISTS "Users can access their own purchases" ON purchases;
DROP POLICY IF EXISTS "Users can insert their own purchases" ON purchases;
DROP POLICY IF EXISTS "Users can update their own purchases" ON purchases;
DROP POLICY IF EXISTS "Users can read their own purchases" ON purchases;
DROP POLICY IF EXISTS "Admins can access all purchases" ON purchases;

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

-- 管理者用の関数を作成（ビューの代わりに使用）
CREATE OR REPLACE FUNCTION get_admin_purchases()
RETURNS TABLE (
    id UUID,
    user_id TEXT,
    email TEXT,
    full_name TEXT,
    nft_quantity INTEGER,
    amount_usd NUMERIC,
    payment_status TEXT,
    admin_approved BOOLEAN,
    admin_approved_at TIMESTAMP WITH TIME ZONE,
    admin_approved_by TEXT,
    payment_proof_url TEXT,
    user_notes TEXT,
    admin_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    confirmed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    has_approved_nft BOOLEAN
) AS $$
BEGIN
    -- 管理者権限チェック
    IF NOT EXISTS (
        SELECT 1 FROM admins a 
        JOIN users u ON u.email = a.email
        WHERE u.id = auth.uid() AND a.is_active = TRUE
    ) THEN
        RAISE EXCEPTION '管理者権限が必要です';
    END IF;
    
    -- 全ての購入データを返す
    RETURN QUERY
    SELECT 
        p.id,
        p.user_id,
        u.email,
        u.full_name,
        p.nft_quantity,
        p.amount_usd,
        p.payment_status,
        p.admin_approved,
        p.admin_approved_at,
        p.admin_approved_by,
        p.payment_proof_url,
        p.user_notes,
        p.admin_notes,
        p.created_at,
        p.confirmed_at,
        p.completed_at,
        u.has_approved_nft
    FROM purchases p
    JOIN users u ON p.user_id = u.user_id
    ORDER BY p.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 現在のポリシー状況を確認
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('purchases', 'users', 'admins')
ORDER BY tablename, policyname;

-- テスト用のデータ確認
SELECT 'Current purchases count:' as info, COUNT(*) as count FROM purchases;
SELECT 'Current users count:' as info, COUNT(*) as count FROM users;
SELECT 'Current admins count:' as info, COUNT(*) as count FROM admins;

-- 管理者権限テスト（実際の管理者メールアドレスでテスト）
SELECT 'Admin check test:' as info, is_admin('basarasystems@gmail.com') as is_admin_result;
