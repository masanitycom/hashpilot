-- Phase 1: 新機能用テーブルの作成（既存テーブルに影響なし）

-- 1. 日利ログテーブル
CREATE TABLE IF NOT EXISTS daily_yield_log (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL UNIQUE,
    yield_rate DECIMAL(5,4) NOT NULL, -- 例: 0.0150 (1.5%)
    margin_rate DECIMAL(3,2) NOT NULL, -- 0.30 (30%) or 0.40 (40%)
    user_rate DECIMAL(5,4) NOT NULL, -- yield_rate * (1 - margin_rate)
    is_month_end BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES auth.users(id)
);

-- 2. ユーザーサイクル管理テーブル（既存usersテーブルのuser_idはtext型）
CREATE TABLE IF NOT EXISTS affiliate_cycle (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL, -- text型に変更（既存usersテーブルに合わせる）
    cycle_number INTEGER NOT NULL DEFAULT 1,
    phase VARCHAR(10) NOT NULL DEFAULT 'USDT' CHECK (phase IN ('USDT', 'HOLD')),
    cum_usdt DECIMAL(10,2) NOT NULL DEFAULT 0.00, -- 累積USDT
    available_usdt DECIMAL(10,2) NOT NULL DEFAULT 0.00, -- 受取可能USDT
    total_nft_count INTEGER NOT NULL DEFAULT 0, -- 保有NFT総数
    auto_nft_count INTEGER NOT NULL DEFAULT 0, -- 自動購入NFT数
    manual_nft_count INTEGER NOT NULL DEFAULT 0, -- 手動購入NFT数
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- 3. システム設定テーブル
CREATE TABLE IF NOT EXISTS system_config (
    key VARCHAR(50) PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_by UUID REFERENCES auth.users(id)
);

-- 4. NFT保有テーブル（purchasesとは別管理）
CREATE TABLE IF NOT EXISTS nft_holdings (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL, -- text型に変更（既存usersテーブルに合わせる）
    nft_type VARCHAR(20) NOT NULL CHECK (nft_type IN ('manual_purchase', 'auto_buy')),
    purchase_amount DECIMAL(10,2) NOT NULL DEFAULT 1100.00,
    purchase_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    cycle_number INTEGER NOT NULL DEFAULT 1,
    transaction_id VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- インデックス作成
CREATE INDEX IF NOT EXISTS idx_daily_yield_log_date ON daily_yield_log(date);
CREATE INDEX IF NOT EXISTS idx_affiliate_cycle_user_id ON affiliate_cycle(user_id);
CREATE INDEX IF NOT EXISTS idx_nft_holdings_user_id ON nft_holdings(user_id);
CREATE INDEX IF NOT EXISTS idx_nft_holdings_type ON nft_holdings(nft_type);

-- システム設定の初期値
INSERT INTO system_config (key, value, description) VALUES
('new_system_enabled', 'false', '新アフィリエイトシステムの有効/無効'),
('auto_nft_enabled', 'false', 'NFT自動購入機能の有効/無効'),
('daily_processing_enabled', 'false', '日次処理の有効/無効'),
('monthly_processing_enabled', 'false', '月次処理の有効/無効')
ON CONFLICT (key) DO NOTHING;

-- RLS設定
ALTER TABLE daily_yield_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_cycle ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE nft_holdings ENABLE ROW LEVEL SECURITY;

-- RLSポリシー（auth.uid()はUUID型なので、text型のuser_idと比較する際はキャストが必要）
-- daily_yield_log: 管理者のみ作成、全員読み取り可能
CREATE POLICY "daily_yield_log_select" ON daily_yield_log FOR SELECT USING (true);
CREATE POLICY "daily_yield_log_insert" ON daily_yield_log FOR INSERT 
WITH CHECK (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text));

-- affiliate_cycle: ユーザーは自分のデータのみ
CREATE POLICY "affiliate_cycle_select" ON affiliate_cycle FOR SELECT 
USING (user_id = auth.uid()::text OR EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text));
CREATE POLICY "affiliate_cycle_update" ON affiliate_cycle FOR UPDATE 
USING (user_id = auth.uid()::text OR EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text));

-- system_config: 管理者のみ更新、全員読み取り可能
CREATE POLICY "system_config_select" ON system_config FOR SELECT USING (true);
CREATE POLICY "system_config_update" ON system_config FOR UPDATE 
WITH CHECK (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text));

-- nft_holdings: ユーザーは自分のデータのみ
CREATE POLICY "nft_holdings_select" ON nft_holdings FOR SELECT 
USING (user_id = auth.uid()::text OR EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text));
CREATE POLICY "nft_holdings_insert" ON nft_holdings FOR INSERT 
WITH CHECK (user_id = auth.uid()::text OR EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text));

-- 既存ユーザーのサイクルデータ作成
INSERT INTO affiliate_cycle (user_id, total_nft_count, manual_nft_count)
SELECT 
    u.user_id,
    COALESCE(p.nft_count, 0),
    COALESCE(p.nft_count, 0)
FROM users u
LEFT JOIN (
    SELECT user_id, COUNT(*) as nft_count
    FROM purchases 
    GROUP BY user_id
) p ON u.user_id = p.user_id
ON CONFLICT (user_id) DO NOTHING;

-- 既存購入データをnft_holdingsに移行（statusカラムを削除）
INSERT INTO nft_holdings (user_id, nft_type, purchase_amount, purchase_date, transaction_id)
SELECT 
    user_id,
    'manual_purchase',
    amount,
    created_at,
    transaction_id
FROM purchases
ON CONFLICT DO NOTHING;

COMMENT ON TABLE daily_yield_log IS '日利率ログ - 管理者が毎日入力';
COMMENT ON TABLE affiliate_cycle IS 'ユーザーサイクル管理 - USDT/HOLDフェーズ、NFT数管理';
COMMENT ON TABLE system_config IS 'システム設定 - 新機能のON/OFF制御';
COMMENT ON TABLE nft_holdings IS 'NFT保有履歴 - 手動購入/自動購入の区別';
