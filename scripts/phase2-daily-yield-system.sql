-- Phase 2: 日利システムの実装

-- 1. user_daily_profitテーブル
CREATE TABLE IF NOT EXISTS user_daily_profit (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    date DATE NOT NULL,
    yield_rate DECIMAL(5,4) NOT NULL,
    user_rate DECIMAL(5,4) NOT NULL,
    base_amount DECIMAL(10,2) NOT NULL, -- NFT数 × 1100
    daily_profit DECIMAL(10,2) NOT NULL,
    phase VARCHAR(10) NOT NULL CHECK (phase IN ('USDT', 'HOLD')),
    is_paid BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, date),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- 2. company_daily_profitテーブル
CREATE TABLE IF NOT EXISTS company_daily_profit (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL UNIQUE,
    total_user_profit DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_company_profit DECIMAL(12,2) NOT NULL DEFAULT 0,
    margin_rate DECIMAL(3,2) NOT NULL,
    total_base_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    user_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. affiliate_rewardテーブル
CREATE TABLE IF NOT EXISTS affiliate_reward (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    referral_user_id TEXT NOT NULL,
    date DATE NOT NULL,
    level INTEGER NOT NULL CHECK (level IN (1, 2, 3)),
    reward_rate DECIMAL(4,3) NOT NULL, -- 0.250, 0.100, 0.050
    base_profit DECIMAL(10,2) NOT NULL,
    reward_amount DECIMAL(10,2) NOT NULL,
    phase VARCHAR(10) NOT NULL CHECK (phase IN ('USDT', 'HOLD')),
    is_paid BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, referral_user_id, date, level),
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (referral_user_id) REFERENCES users(user_id)
);

-- インデックス作成
CREATE INDEX IF NOT EXISTS idx_user_daily_profit_user_date ON user_daily_profit(user_id, date);
CREATE INDEX IF NOT EXISTS idx_user_daily_profit_date ON user_daily_profit(date);
CREATE INDEX IF NOT EXISTS idx_company_daily_profit_date ON company_daily_profit(date);
CREATE INDEX IF NOT EXISTS idx_affiliate_reward_user_date ON affiliate_reward(user_id, date);
CREATE INDEX IF NOT EXISTS idx_affiliate_reward_referral_date ON affiliate_reward(referral_user_id, date);

-- RLS設定
ALTER TABLE user_daily_profit ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_daily_profit ENABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_reward ENABLE ROW LEVEL SECURITY;

-- 既存ポリシーを削除してから作成
DROP POLICY IF EXISTS "user_daily_profit_select" ON user_daily_profit;
DROP POLICY IF EXISTS "company_daily_profit_select" ON company_daily_profit;
DROP POLICY IF EXISTS "affiliate_reward_select" ON affiliate_reward;

-- RLSポリシー
CREATE POLICY "user_daily_profit_select" ON user_daily_profit FOR SELECT 
USING (user_id = auth.uid()::text OR EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text));

CREATE POLICY "company_daily_profit_select" ON company_daily_profit FOR SELECT 
USING (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text));

CREATE POLICY "affiliate_reward_select" ON affiliate_reward FOR SELECT 
USING (user_id = auth.uid()::text OR EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text));

-- 4. 日利投稿関数（管理者用）
CREATE OR REPLACE FUNCTION admin_post_yield(
    p_date DATE,
    p_yield_rate DECIMAL(5,4),
    p_margin_rate DECIMAL(3,2),
    p_is_month_end BOOLEAN DEFAULT FALSE
) RETURNS JSON AS $$
DECLARE
    v_user_rate DECIMAL(5,4);
    v_total_users INTEGER;
    v_total_base_amount DECIMAL(12,2);
    v_total_user_profit DECIMAL(12,2);
    v_total_company_profit DECIMAL(12,2);
    v_result JSON;
BEGIN
    -- 管理者権限チェック
    IF NOT EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text) THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;
    
    -- ユーザー利率計算
    v_user_rate := p_yield_rate * (1 - p_margin_rate);
    
    -- 日利ログに記録
    INSERT INTO daily_yield_log (date, yield_rate, margin_rate, user_rate, is_month_end, created_by)
    VALUES (p_date, p_yield_rate, p_margin_rate, v_user_rate, p_is_month_end, auth.uid())
    ON CONFLICT (date) DO UPDATE SET
        yield_rate = p_yield_rate,
        margin_rate = p_margin_rate,
        user_rate = v_user_rate,
        is_month_end = p_is_month_end,
        created_by = auth.uid();
    
    -- ユーザー日利計算
    INSERT INTO user_daily_profit (user_id, date, yield_rate, user_rate, base_amount, daily_profit, phase)
    SELECT 
        ac.user_id,
        p_date,
        p_yield_rate,
        v_user_rate,
        ac.total_nft_count * 1100.00,
        (ac.total_nft_count * 1100.00) * v_user_rate,
        ac.phase
    FROM affiliate_cycle ac
    WHERE ac.total_nft_count > 0
    ON CONFLICT (user_id, date) DO UPDATE SET
        yield_rate = p_yield_rate,
        user_rate = v_user_rate,
        base_amount = (SELECT total_nft_count FROM affiliate_cycle WHERE user_id = user_daily_profit.user_id) * 1100.00,
        daily_profit = ((SELECT total_nft_count FROM affiliate_cycle WHERE user_id = user_daily_profit.user_id) * 1100.00) * v_user_rate,
        phase = (SELECT phase FROM affiliate_cycle WHERE user_id = user_daily_profit.user_id);
    
    -- 紹介報酬計算（3段階）
    -- Level 1 (25%)
    INSERT INTO affiliate_reward (user_id, referral_user_id, date, level, reward_rate, base_profit, reward_amount, phase)
    SELECT 
        u1.user_id,
        udp.user_id,
        p_date,
        1,
        0.250,
        udp.daily_profit,
        udp.daily_profit * 0.250,
        (SELECT phase FROM affiliate_cycle WHERE user_id = u1.user_id)
    FROM user_daily_profit udp
    JOIN users u1 ON udp.user_id = u1.referrer_user_id
    WHERE udp.date = p_date
    ON CONFLICT (user_id, referral_user_id, date, level) DO UPDATE SET
        base_profit = EXCLUDED.base_profit,
        reward_amount = EXCLUDED.reward_amount,
        phase = EXCLUDED.phase;
    
    -- Level 2 (10%)
    INSERT INTO affiliate_reward (user_id, referral_user_id, date, level, reward_rate, base_profit, reward_amount, phase)
    SELECT 
        u2.user_id,
        udp.user_id,
        p_date,
        2,
        0.100,
        udp.daily_profit,
        udp.daily_profit * 0.100,
        (SELECT phase FROM affiliate_cycle WHERE user_id = u2.user_id)
    FROM user_daily_profit udp
    JOIN users u1 ON udp.user_id = u1.referrer_user_id
    JOIN users u2 ON u1.user_id = u2.referrer_user_id
    WHERE udp.date = p_date
    ON CONFLICT (user_id, referral_user_id, date, level) DO UPDATE SET
        base_profit = EXCLUDED.base_profit,
        reward_amount = EXCLUDED.reward_amount,
        phase = EXCLUDED.phase;
    
    -- Level 3 (5%)
    INSERT INTO affiliate_reward (user_id, referral_user_id, date, level, reward_rate, base_profit, reward_amount, phase)
    SELECT 
        u3.user_id,
        udp.user_id,
        p_date,
        3,
        0.050,
        udp.daily_profit,
        udp.daily_profit * 0.050,
        (SELECT phase FROM affiliate_cycle WHERE user_id = u3.user_id)
    FROM user_daily_profit udp
    JOIN users u1 ON udp.user_id = u1.referrer_user_id
    JOIN users u2 ON u1.user_id = u2.referrer_user_id
    JOIN users u3 ON u2.user_id = u3.referrer_user_id
    WHERE udp.date = p_date
    ON CONFLICT (user_id, referral_user_id, date, level) DO UPDATE SET
        base_profit = EXCLUDED.base_profit,
        reward_amount = EXCLUDED.reward_amount,
        phase = EXCLUDED.phase;
    
    -- 会社利益計算
    SELECT 
        COUNT(*),
        SUM(base_amount),
        SUM(daily_profit)
    INTO v_total_users, v_total_base_amount, v_total_user_profit
    FROM user_daily_profit
    WHERE date = p_date;
    
    v_total_company_profit := v_total_base_amount * p_yield_rate - v_total_user_profit;
    
    INSERT INTO company_daily_profit (date, total_user_profit, total_company_profit, margin_rate, total_base_amount, user_count)
    VALUES (p_date, v_total_user_profit, v_total_company_profit, p_margin_rate, v_total_base_amount, v_total_users)
    ON CONFLICT (date) DO UPDATE SET
        total_user_profit = v_total_user_profit,
        total_company_profit = v_total_company_profit,
        margin_rate = p_margin_rate,
        total_base_amount = v_total_base_amount,
        user_count = v_total_users;
    
    v_result := json_build_object(
        'success', true,
        'date', p_date,
        'yield_rate', p_yield_rate,
        'user_rate', v_user_rate,
        'total_users', v_total_users,
        'total_user_profit', v_total_user_profit,
        'total_company_profit', v_total_company_profit
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE user_daily_profit IS 'ユーザー日利記録';
COMMENT ON TABLE company_daily_profit IS '会社日利記録';
COMMENT ON TABLE affiliate_reward IS '紹介報酬記録';
COMMENT ON FUNCTION admin_post_yield IS '管理者用日利投稿関数';
