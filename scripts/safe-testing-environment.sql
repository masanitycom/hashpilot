-- 本番環境での安全なテスト環境構築
-- ユーザー認証や紹介関係は一切触らない

-- 1. テスト用プレフィックスでテーブルを作成（本番データと分離）
CREATE TABLE IF NOT EXISTS test_daily_yield_log (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL UNIQUE,
    yield_rate DECIMAL(5,4) NOT NULL,
    margin_rate DECIMAL(3,2) NOT NULL,
    user_rate DECIMAL(5,4) NOT NULL,
    is_month_end BOOLEAN DEFAULT FALSE,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    test_mode BOOLEAN DEFAULT TRUE
);

-- 2. テスト用ユーザー日利記録
CREATE TABLE IF NOT EXISTS test_user_daily_profit (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    date DATE NOT NULL,
    yield_rate DECIMAL(5,4) NOT NULL,
    user_rate DECIMAL(5,4) NOT NULL,
    base_amount DECIMAL(10,2) NOT NULL,
    daily_profit DECIMAL(10,2) NOT NULL,
    phase VARCHAR(10) NOT NULL CHECK (phase IN ('USDT', 'HOLD')),
    is_paid BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    test_mode BOOLEAN DEFAULT TRUE,
    UNIQUE(user_id, date)
);

-- 3. テスト用紹介報酬記録
CREATE TABLE IF NOT EXISTS test_affiliate_reward (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    referral_user_id TEXT NOT NULL,
    date DATE NOT NULL,
    level INTEGER NOT NULL CHECK (level IN (1, 2, 3)),
    reward_rate DECIMAL(4,3) NOT NULL,
    base_profit DECIMAL(10,2) NOT NULL,
    reward_amount DECIMAL(10,2) NOT NULL,
    phase VARCHAR(10) NOT NULL CHECK (phase IN ('USDT', 'HOLD')),
    is_paid BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    test_mode BOOLEAN DEFAULT TRUE,
    UNIQUE(user_id, referral_user_id, date, level)
);

-- 4. テスト用会社利益記録
CREATE TABLE IF NOT EXISTS test_company_daily_profit (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL UNIQUE,
    total_user_profit DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_company_profit DECIMAL(12,2) NOT NULL DEFAULT 0,
    margin_rate DECIMAL(3,2) NOT NULL,
    total_base_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
    user_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    test_mode BOOLEAN DEFAULT TRUE
);

-- 5. 安全なテスト実行関数
CREATE OR REPLACE FUNCTION admin_test_yield_calculation(
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
    v_total_affiliate_profit DECIMAL(12,2);
    v_result JSON;
BEGIN
    -- 管理者権限チェック
    IF NOT EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text) THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;
    
    -- ユーザー利率計算（修正版）
    v_user_rate := (p_yield_rate - p_margin_rate) * 0.6;
    
    -- テスト用テーブルに記録
    INSERT INTO test_daily_yield_log (date, yield_rate, margin_rate, user_rate, is_month_end, created_by)
    VALUES (p_date, p_yield_rate, p_margin_rate, v_user_rate, p_is_month_end, auth.uid())
    ON CONFLICT (date) DO UPDATE SET
        yield_rate = p_yield_rate,
        margin_rate = p_margin_rate,
        user_rate = v_user_rate,
        is_month_end = p_is_month_end,
        created_by = auth.uid();
    
    -- テスト用ユーザー日利計算（既存のaffiliate_cycleデータを参照するが、テスト用テーブルに保存）
    INSERT INTO test_user_daily_profit (user_id, date, yield_rate, user_rate, base_amount, daily_profit, phase)
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
        base_amount = EXCLUDED.base_amount,
        daily_profit = EXCLUDED.daily_profit,
        phase = EXCLUDED.phase;
    
    -- テスト用紹介報酬計算
    -- Level 1
    INSERT INTO test_affiliate_reward (user_id, referral_user_id, date, level, reward_rate, base_profit, reward_amount, phase)
    SELECT 
        u1.user_id,
        tudp.user_id,
        p_date,
        1,
        0.250,
        tudp.base_amount * (p_yield_rate - p_margin_rate),
        tudp.base_amount * (p_yield_rate - p_margin_rate) * 0.250,
        COALESCE((SELECT phase FROM affiliate_cycle WHERE user_id = u1.user_id), 'USDT')
    FROM test_user_daily_profit tudp
    JOIN users u1 ON tudp.user_id = u1.referrer_user_id
    WHERE tudp.date = p_date
    ON CONFLICT (user_id, referral_user_id, date, level) DO UPDATE SET
        base_profit = EXCLUDED.base_profit,
        reward_amount = EXCLUDED.reward_amount;
    
    -- Level 2 & 3も同様に実装...
    
    -- 統計計算
    SELECT 
        COUNT(*),
        SUM(base_amount),
        SUM(daily_profit)
    INTO v_total_users, v_total_base_amount, v_total_user_profit
    FROM test_user_daily_profit
    WHERE date = p_date;
    
    -- テスト用アフィリエイト報酬総額
    SELECT 
        COALESCE(SUM(reward_amount), 0)
    INTO v_total_affiliate_profit
    FROM test_affiliate_reward
    WHERE date = p_date;
    
    -- テスト用会社利益
    v_total_company_profit := v_total_base_amount * p_margin_rate + v_total_base_amount * (p_yield_rate - p_margin_rate) * 0.1;
    
    INSERT INTO test_company_daily_profit (date, total_user_profit, total_company_profit, margin_rate, total_base_amount, user_count)
    VALUES (p_date, v_total_user_profit, v_total_company_profit, p_margin_rate, v_total_base_amount, v_total_users)
    ON CONFLICT (date) DO UPDATE SET
        total_user_profit = v_total_user_profit,
        total_company_profit = v_total_company_profit,
        margin_rate = p_margin_rate,
        total_base_amount = v_total_base_amount,
        user_count = v_total_users;
    
    v_result := json_build_object(
        'success', true,
        'test_mode', true,
        'message', 'テスト実行完了 - 本番データには影響しません',
        'date', p_date,
        'yield_rate', p_yield_rate,
        'margin_rate', p_margin_rate,
        'user_rate', v_user_rate,
        'total_users', v_total_users,
        'total_user_profit', v_total_user_profit,
        'total_affiliate_profit', v_total_affiliate_profit,
        'total_company_profit', v_total_company_profit,
        'calculation_breakdown', json_build_object(
            'effective_rate', p_yield_rate - p_margin_rate,
            'user_portion', 0.6,
            'affiliate_portion', 0.3,
            'pool_portion', 0.1
        )
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. テストデータクリア関数
CREATE OR REPLACE FUNCTION admin_clear_test_data() RETURNS JSON AS $$
BEGIN
    -- 管理者権限チェック
    IF NOT EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text) THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;
    
    DELETE FROM test_affiliate_reward;
    DELETE FROM test_user_daily_profit;
    DELETE FROM test_company_daily_profit;
    DELETE FROM test_daily_yield_log;
    
    RETURN json_build_object(
        'success', true,
        'message', 'テストデータをすべてクリアしました'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. テスト結果表示用ビュー
CREATE OR REPLACE VIEW test_yield_summary AS
SELECT 
    tdyl.date,
    tdyl.yield_rate,
    tdyl.margin_rate,
    tdyl.user_rate,
    tcdp.user_count as total_users,
    tcdp.total_user_profit,
    tcdp.total_company_profit,
    COALESCE(tar_summary.total_affiliate_rewards, 0) as total_affiliate_rewards,
    tdyl.created_at
FROM test_daily_yield_log tdyl
LEFT JOIN test_company_daily_profit tcdp ON tdyl.date = tcdp.date
LEFT JOIN (
    SELECT 
        date,
        SUM(reward_amount) as total_affiliate_rewards
    FROM test_affiliate_reward
    GROUP BY date
) tar_summary ON tdyl.date = tar_summary.date
ORDER BY tdyl.date DESC;

COMMENT ON FUNCTION admin_test_yield_calculation IS '本番データに影響しない安全なテスト実行関数';
COMMENT ON FUNCTION admin_clear_test_data IS 'テストデータのクリア関数';
COMMENT ON VIEW test_yield_summary IS 'テスト結果の要約表示';