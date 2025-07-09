-- 既存のadminsテーブルを削除して再作成
DROP TABLE IF EXISTS admins CASCADE;

-- 管理者テーブルを修正（外部キー制約を緩和）
CREATE TABLE admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT, -- 外部キー制約を削除
    email TEXT NOT NULL UNIQUE,
    role TEXT DEFAULT 'admin',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);

-- 管理者用のRLSポリシー
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;

-- 管理者は自分の情報を見ることができる
CREATE POLICY "Admins can read admin data" 
ON admins FOR SELECT 
TO authenticated 
USING (
    email = (
        SELECT email FROM auth.users WHERE id = auth.uid()
    )
);

-- 初期管理者を作成（実際のメールアドレスに変更してください）
INSERT INTO admins (user_id, email, role) 
VALUES 
    ('ADMIN1', 'admin@hashpilot.com', 'super_admin'),
    ('ADMIN2', 'basarasystems@gmail.com', 'admin') -- 実際の管理者
ON CONFLICT (email) DO NOTHING;

-- 管理者チェック関数を作成
CREATE OR REPLACE FUNCTION is_admin(user_email TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM admins 
        WHERE email = user_email AND is_active = TRUE
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 承認関数を修正（管理者チェックを追加）
CREATE OR REPLACE FUNCTION approve_user_nft(
    purchase_id UUID,
    admin_email TEXT,
    admin_notes_text TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    target_user_id TEXT;
    purchase_exists BOOLEAN;
BEGIN
    -- 管理者権限チェック
    IF NOT is_admin(admin_email) THEN
        RAISE EXCEPTION '管理者権限がありません';
    END IF;
    
    -- 購入レコードの存在確認とuser_id取得
    SELECT user_id INTO target_user_id
    FROM purchases 
    WHERE id = purchase_id AND admin_approved = FALSE;
    
    IF target_user_id IS NULL THEN
        RAISE EXCEPTION '承認対象の購入が見つかりません';
    END IF;
    
    -- 購入を承認
    UPDATE purchases 
    SET 
        admin_approved = TRUE,
        admin_approved_at = NOW(),
        admin_approved_by = admin_email,
        admin_notes = admin_notes_text,
        payment_status = 'approved'
    WHERE id = purchase_id;
    
    -- ユーザーのNFT所有状況を更新
    UPDATE users 
    SET 
        has_approved_nft = TRUE,
        first_nft_approved_at = COALESCE(first_nft_approved_at, NOW())
    WHERE user_id = target_user_id;
    
    RAISE NOTICE 'NFT承認完了: user_id=%, admin=%', target_user_id, admin_email;
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 管理者一覧を確認
SELECT * FROM admins;

-- 現在のユーザー状況を確認
SELECT 
    u.user_id,
    u.email,
    u.has_approved_nft,
    COUNT(p.id) as purchase_count,
    COUNT(CASE WHEN p.admin_approved THEN 1 END) as approved_purchases
FROM users u
LEFT JOIN purchases p ON u.user_id = p.user_id
GROUP BY u.user_id, u.email, u.has_approved_nft
ORDER BY u.created_at DESC;
