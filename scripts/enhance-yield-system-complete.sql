-- 日利システムの完全な拡張

-- 1. ユーザー月次報酬サマリーテーブル
CREATE TABLE IF NOT EXISTS user_monthly_rewards (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    total_daily_profit DECIMAL(10,2) NOT NULL DEFAULT 0,
    total_referral_rewards DECIMAL(10,2) NOT NULL DEFAULT 0,
    total_rewards DECIMAL(10,2) NOT NULL DEFAULT 0,
    is_paid BOOLEAN DEFAULT FALSE,
    paid_at TIMESTAMP WITH TIME ZONE,
    paid_by TEXT,
    payment_transaction_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, year, month),
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- 2. 日利履歴ビュー（ユーザー用）
CREATE OR REPLACE VIEW user_daily_profit_history AS
SELECT 
    udp.user_id,
    udp.date,
    udp.yield_rate * 100 as yield_rate_percent,
    udp.user_rate * 100 as user_rate_percent,
    udp.base_amount,
    udp.daily_profit,
    udp.phase,
    udp.created_at,
    -- 紹介報酬も含める
    COALESCE(ar.total_referral_reward, 0) as referral_reward,
    udp.daily_profit + COALESCE(ar.total_referral_reward, 0) as total_daily_reward
FROM user_daily_profit udp
LEFT JOIN (
    SELECT 
        user_id,
        date,
        SUM(reward_amount) as total_referral_reward
    FROM affiliate_reward
    GROUP BY user_id, date
) ar ON udp.user_id = ar.user_id AND udp.date = ar.date;

-- 3. 管理者用報酬管理ビュー
CREATE OR REPLACE VIEW admin_monthly_rewards_view AS
SELECT 
    umr.user_id,
    u.email,
    u.full_name,
    umr.year,
    umr.month,
    umr.total_daily_profit,
    umr.total_referral_rewards,
    umr.total_rewards,
    umr.is_paid,
    umr.paid_at,
    umr.paid_by,
    umr.payment_transaction_id,
    umr.created_at,
    -- 当月の詳細統計
    COUNT(udp.id) as days_count,
    AVG(udp.yield_rate * 100) as avg_yield_rate,
    MIN(udp.daily_profit) as min_daily_profit,
    MAX(udp.daily_profit) as max_daily_profit
FROM user_monthly_rewards umr
JOIN users u ON umr.user_id = u.user_id
LEFT JOIN user_daily_profit udp ON umr.user_id = udp.user_id 
    AND EXTRACT(YEAR FROM udp.date) = umr.year 
    AND EXTRACT(MONTH FROM udp.date) = umr.month
GROUP BY umr.id, u.email, u.full_name, umr.user_id, umr.year, umr.month, 
         umr.total_daily_profit, umr.total_referral_rewards, umr.total_rewards,
         umr.is_paid, umr.paid_at, umr.paid_by, umr.payment_transaction_id, umr.created_at;

-- 4. 月次報酬集計関数
CREATE OR REPLACE FUNCTION calculate_monthly_rewards(
    p_year INTEGER,
    p_month INTEGER
) RETURNS JSON AS $$
DECLARE
    v_result JSON;
    v_total_users INTEGER;
    v_total_rewards DECIMAL(12,2);
BEGIN
    -- 管理者権限チェック
    IF NOT EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text) THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;
    
    -- 月次報酬を計算して保存
    INSERT INTO user_monthly_rewards (user_id, year, month, total_daily_profit, total_referral_rewards, total_rewards)
    SELECT 
        udp.user_id,
        p_year,
        p_month,
        COALESCE(SUM(udp.daily_profit), 0) as total_daily_profit,
        COALESCE(SUM(ar.reward_amount), 0) as total_referral_rewards,
        COALESCE(SUM(udp.daily_profit), 0) + COALESCE(SUM(ar.reward_amount), 0) as total_rewards
    FROM user_daily_profit udp
    LEFT JOIN affiliate_reward ar ON udp.user_id = ar.user_id AND udp.date = ar.date
    WHERE EXTRACT(YEAR FROM udp.date) = p_year 
      AND EXTRACT(MONTH FROM udp.date) = p_month
    GROUP BY udp.user_id
    ON CONFLICT (user_id, year, month) DO UPDATE SET
        total_daily_profit = EXCLUDED.total_daily_profit,
        total_referral_rewards = EXCLUDED.total_referral_rewards,
        total_rewards = EXCLUDED.total_rewards,
        updated_at = NOW();
    
    -- 結果統計
    SELECT 
        COUNT(*),
        SUM(total_rewards)
    INTO v_total_users, v_total_rewards
    FROM user_monthly_rewards
    WHERE year = p_year AND month = p_month;
    
    v_result := json_build_object(
        'success', true,
        'year', p_year,
        'month', p_month,
        'total_users', v_total_users,
        'total_rewards', v_total_rewards
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. 報酬支払い完了関数
CREATE OR REPLACE FUNCTION mark_reward_as_paid(
    p_user_id TEXT,
    p_year INTEGER,
    p_month INTEGER,
    p_transaction_id TEXT
) RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    -- 管理者権限チェック
    IF NOT EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text) THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;
    
    UPDATE user_monthly_rewards
    SET 
        is_paid = true,
        paid_at = NOW(),
        paid_by = auth.uid()::text,
        payment_transaction_id = p_transaction_id,
        updated_at = NOW()
    WHERE user_id = p_user_id AND year = p_year AND month = p_month;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reward record not found';
    END IF;
    
    v_result := json_build_object(
        'success', true,
        'message', 'Payment marked as completed'
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. ユーザー日利統計関数
CREATE OR REPLACE FUNCTION get_user_daily_profit_stats(
    p_user_id TEXT,
    p_days INTEGER DEFAULT 30
) RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    -- ユーザー本人または管理者のみアクセス可能
    IF p_user_id != auth.uid()::text AND NOT EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text) THEN
        RAISE EXCEPTION 'Access denied';
    END IF;
    
    SELECT json_build_object(
        'daily_profits', json_agg(
            json_build_object(
                'date', date,
                'yield_rate', yield_rate_percent,
                'daily_profit', daily_profit,
                'referral_reward', referral_reward,
                'total_reward', total_daily_reward
            ) ORDER BY date DESC
        ),
        'summary', json_build_object(
            'total_days', COUNT(*),
            'total_profit', SUM(daily_profit),
            'total_referral', SUM(referral_reward),
            'total_rewards', SUM(total_daily_reward),
            'avg_daily_profit', AVG(daily_profit),
            'max_daily_profit', MAX(daily_profit),
            'min_daily_profit', MIN(daily_profit)
        )
    )
    INTO v_result
    FROM user_daily_profit_history
    WHERE user_id = p_user_id 
      AND date >= CURRENT_DATE - INTERVAL '%s days' % p_days;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- インデックス作成
CREATE INDEX IF NOT EXISTS idx_user_monthly_rewards_user_year_month ON user_monthly_rewards(user_id, year, month);
CREATE INDEX IF NOT EXISTS idx_user_monthly_rewards_is_paid ON user_monthly_rewards(is_paid);
CREATE INDEX IF NOT EXISTS idx_user_daily_profit_date_desc ON user_daily_profit(date DESC);

-- RLS設定
ALTER TABLE user_monthly_rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_monthly_rewards_select" ON user_monthly_rewards;
CREATE POLICY "user_monthly_rewards_select" ON user_monthly_rewards FOR SELECT 
USING (user_id = auth.uid()::text OR EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text));

-- マイナス日利対応のためのチェック制約を削除（既に存在する場合）
ALTER TABLE user_daily_profit DROP CONSTRAINT IF EXISTS user_daily_profit_daily_profit_check;
ALTER TABLE affiliate_reward DROP CONSTRAINT IF EXISTS affiliate_reward_reward_amount_check;

COMMENT ON TABLE user_monthly_rewards IS 'ユーザー月次報酬サマリー';
COMMENT ON FUNCTION calculate_monthly_rewards IS '月次報酬集計関数';
COMMENT ON FUNCTION mark_reward_as_paid IS '報酬支払い完了マーク関数';
COMMENT ON FUNCTION get_user_daily_profit_stats IS 'ユーザー日利統計取得関数';
