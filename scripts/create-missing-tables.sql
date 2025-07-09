-- 必要なテーブルを作成（存在しない場合のみ）

-- monthly_rewards テーブル
CREATE TABLE IF NOT EXISTS monthly_rewards (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    reward_amount DECIMAL(10,2) DEFAULT 0,
    reward_month DATE NOT NULL,
    level_1_bonus DECIMAL(10,2) DEFAULT 0,
    level_2_bonus DECIMAL(10,2) DEFAULT 0,
    level_3_bonus DECIMAL(10,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- user_daily_profit テーブル
CREATE TABLE IF NOT EXISTS user_daily_profit (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    profit_date DATE NOT NULL,
    daily_profit DECIMAL(10,2) DEFAULT 0,
    investment_amount DECIMAL(10,2) DEFAULT 0,
    profit_rate DECIMAL(5,4) DEFAULT 0.0020, -- 0.2%
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, profit_date)
);

-- インデックスを作成
CREATE INDEX IF NOT EXISTS idx_monthly_rewards_user_id ON monthly_rewards(user_id);
CREATE INDEX IF NOT EXISTS idx_monthly_rewards_month ON monthly_rewards(reward_month);
CREATE INDEX IF NOT EXISTS idx_user_daily_profit_user_id ON user_daily_profit(user_id);
CREATE INDEX IF NOT EXISTS idx_user_daily_profit_date ON user_daily_profit(profit_date);

-- RLS を有効化
ALTER TABLE monthly_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_daily_profit ENABLE ROW LEVEL SECURITY;

-- RLS ポリシーを作成
CREATE POLICY "Users can view own monthly rewards" ON monthly_rewards
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can view own daily profits" ON user_daily_profit
    FOR SELECT USING (auth.uid() = user_id);

-- 管理者用ポリシー
CREATE POLICY "Admins can view all monthly rewards" ON monthly_rewards
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM admins 
            WHERE user_id = auth.uid() 
            AND is_active = true
        )
    );

CREATE POLICY "Admins can view all daily profits" ON user_daily_profit
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM admins 
            WHERE user_id = auth.uid() 
            AND is_active = true
        )
    );

-- 権限を付与
GRANT SELECT ON monthly_rewards TO authenticated;
GRANT SELECT ON user_daily_profit TO authenticated;
