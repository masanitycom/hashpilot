-- purchasesテーブルを更新して承認システムを追加
ALTER TABLE purchases 
ADD COLUMN IF NOT EXISTS admin_approved BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS admin_approved_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS admin_approved_by TEXT,
ADD COLUMN IF NOT EXISTS payment_proof_url TEXT,
ADD COLUMN IF NOT EXISTS user_notes TEXT,
ADD COLUMN IF NOT EXISTS admin_notes TEXT;

-- payment_statusの値を更新
ALTER TABLE purchases 
ALTER COLUMN payment_status SET DEFAULT 'pending';

-- 購入承認状態を管理するためのENUM型を作成（既存データとの互換性のため、後で適用）
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'purchase_status') THEN
        CREATE TYPE purchase_status AS ENUM ('pending', 'payment_sent', 'payment_confirmed', 'approved', 'rejected');
    END IF;
END $$;

-- usersテーブルにNFT所有状況を追加
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS has_approved_nft BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS first_nft_approved_at TIMESTAMP WITH TIME ZONE;

-- 管理者テーブルを作成
CREATE TABLE IF NOT EXISTS admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT REFERENCES users(user_id),
    email TEXT NOT NULL,
    role TEXT DEFAULT 'admin',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);

-- 管理者用のRLSポリシー
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can read admin data" 
ON admins FOR SELECT 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM admins a 
        WHERE a.user_id = (
            SELECT user_id FROM users WHERE id = auth.uid()
        )
    )
);

-- 購入データの表示用ビューを作成
CREATE OR REPLACE VIEW purchase_admin_view AS
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

-- NFT承認時にユーザーステータスを更新する関数
CREATE OR REPLACE FUNCTION approve_user_nft(
    purchase_id UUID,
    admin_user_id TEXT,
    admin_notes_text TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    target_user_id TEXT;
    purchase_exists BOOLEAN;
BEGIN
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
        admin_approved_by = admin_user_id,
        admin_notes = admin_notes_text,
        payment_status = 'approved'
    WHERE id = purchase_id;
    
    -- ユーザーのNFT所有状況を更新
    UPDATE users 
    SET 
        has_approved_nft = TRUE,
        first_nft_approved_at = COALESCE(first_nft_approved_at, NOW())
    WHERE user_id = target_user_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 初期管理者を作成（実際の運用では適切なメールアドレスに変更）
INSERT INTO admins (user_id, email, role) 
VALUES ('ADMIN1', 'admin@hashpilot.com', 'super_admin')
ON CONFLICT DO NOTHING;

-- 既存の承認済み購入があれば、ユーザーステータスを更新
UPDATE users 
SET has_approved_nft = TRUE, first_nft_approved_at = NOW()
WHERE user_id IN (
    SELECT DISTINCT user_id 
    FROM purchases 
    WHERE admin_approved = TRUE OR payment_status = 'completed'
);
