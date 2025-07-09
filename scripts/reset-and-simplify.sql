-- HashPilot システムリセット・簡素化スクリプト
-- 基本的なテーブル構造のみを残して、複雑な機能は段階的に追加

-- 1. 基本ユーザーテーブル（シンプル版）
CREATE TABLE IF NOT EXISTS users (
    user_id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    wallet_address TEXT,
    coinw_uid TEXT UNIQUE,
    referrer_id TEXT REFERENCES users(user_id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. NFT保有テーブル（シンプル版）
CREATE TABLE IF NOT EXISTS nft_holdings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT REFERENCES users(user_id),
    quantity INTEGER NOT NULL DEFAULT 1,
    purchase_price_usd NUMERIC(10,2) DEFAULT 1000.00,
    purchase_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    transaction_hash TEXT,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'sold'))
);

-- 3. 管理者テーブル
CREATE TABLE IF NOT EXISTS admins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT REFERENCES users(user_id),
    role TEXT DEFAULT 'admin' CHECK (role IN ('admin', 'super_admin')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. 基本的なRLS設定
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE nft_holdings ENABLE ROW LEVEL SECURITY;
ALTER TABLE admins ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分のデータのみ閲覧可能
CREATE POLICY "Users can view own data" ON users
    FOR SELECT USING (auth.uid()::text = user_id);

CREATE POLICY "Users can view own NFTs" ON nft_holdings
    FOR SELECT USING (auth.uid()::text = user_id);

-- 管理者用のポリシー（後で追加）
CREATE POLICY "Admins can view all data" ON users
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM admins 
            WHERE user_id = auth.uid()::text
        )
    );

-- 5. 基本的な統計関数
CREATE OR REPLACE FUNCTION get_user_stats(target_user_id TEXT)
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'user_id', u.user_id,
        'email', u.email,
        'coinw_uid', u.coinw_uid,
        'nft_count', COALESCE(n.nft_count, 0),
        'total_investment', COALESCE(n.total_investment, 0),
        'referral_count', COALESCE(r.referral_count, 0)
    ) INTO result
    FROM users u
    LEFT JOIN (
        SELECT 
            user_id,
            COUNT(*) as nft_count,
            SUM(purchase_price_usd) as total_investment
        FROM nft_holdings 
        WHERE status = 'active'
        GROUP BY user_id
    ) n ON u.user_id = n.user_id
    LEFT JOIN (
        SELECT 
            referrer_id,
            COUNT(*) as referral_count
        FROM users 
        WHERE referrer_id IS NOT NULL
        GROUP BY referrer_id
    ) r ON u.user_id = r.referrer_id
    WHERE u.user_id = target_user_id;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. 管理者用統計関数
CREATE OR REPLACE FUNCTION admin_get_system_stats()
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    -- 管理者権限チェック
    IF NOT EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text) THEN
        RAISE EXCEPTION 'Access denied: Admin privileges required';
    END IF;
    
    SELECT json_build_object(
        'total_users', (SELECT COUNT(*) FROM users),
        'total_nfts', (SELECT COUNT(*) FROM nft_holdings WHERE status = 'active'),
        'total_investment', (SELECT COALESCE(SUM(purchase_price_usd), 0) FROM nft_holdings WHERE status = 'active'),
        'users_with_referrals', (SELECT COUNT(DISTINCT referrer_id) FROM users WHERE referrer_id IS NOT NULL)
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
