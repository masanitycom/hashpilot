-- buyback_requestsテーブルを作成

-- 1. テーブルの作成
CREATE TABLE IF NOT EXISTS buyback_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    email TEXT NOT NULL,
    request_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- NFT数
    manual_nft_count INTEGER NOT NULL DEFAULT 0,
    auto_nft_count INTEGER NOT NULL DEFAULT 0,
    total_nft_count INTEGER NOT NULL DEFAULT 0,
    
    -- 買い取り金額
    manual_buyback_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    auto_buyback_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    total_buyback_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    
    -- ウォレット情報
    wallet_address TEXT,
    wallet_type TEXT CHECK (wallet_type IN ('metamask', 'coinw', 'other')),
    
    -- ステータス
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'processing', 'completed', 'cancelled', 'rejected')),
    
    -- 処理情報
    processed_by TEXT,
    processed_at TIMESTAMP WITH TIME ZONE,
    transaction_hash TEXT,
    admin_notes TEXT,
    
    -- タイムスタンプ
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. インデックスの作成
CREATE INDEX IF NOT EXISTS idx_buyback_requests_user_id ON buyback_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_buyback_requests_status ON buyback_requests(status);
CREATE INDEX IF NOT EXISTS idx_buyback_requests_created_at ON buyback_requests(created_at DESC);

-- 3. RLS（Row Level Security）の設定
ALTER TABLE buyback_requests ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分の買い取り申請のみ閲覧可能
CREATE POLICY "users_own_buyback_requests" ON buyback_requests
FOR SELECT
TO public
USING (
    user_id IN (
        SELECT user_id FROM users WHERE id = auth.uid()
    )
);

-- ユーザーは自分の買い取り申請を作成可能
CREATE POLICY "users_create_own_buyback_requests" ON buyback_requests
FOR INSERT
TO public
WITH CHECK (
    user_id IN (
        SELECT user_id FROM users WHERE id = auth.uid()
    )
);

-- 管理者は全ての買い取り申請を閲覧・編集可能
CREATE POLICY "admin_all_buyback_requests" ON buyback_requests
FOR ALL
TO public
USING (
    EXISTS (
        SELECT 1 FROM admins 
        WHERE email IN (
            SELECT email FROM auth.users WHERE id = auth.uid()
        )
        AND is_active = true
    )
);

-- 4. 更新時のタイムスタンプ自動更新
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_buyback_requests_updated_at 
    BEFORE UPDATE ON buyback_requests 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- 5. サンプルデータ（テスト用、本番では削除してください）
-- INSERT INTO buyback_requests (user_id, email, manual_nft_count, auto_nft_count, total_nft_count, manual_buyback_amount, auto_buyback_amount, total_buyback_amount, wallet_address, wallet_type)
-- VALUES 
-- ('TEST01', 'test@example.com', 1, 0, 1, 500.00, 0.00, 500.00, '0x1234567890123456789012345678901234567890', 'metamask');