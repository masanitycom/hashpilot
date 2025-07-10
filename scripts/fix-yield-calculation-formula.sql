-- 日利計算式の修正
-- 正しい計算式: (日利率 - 30%) × 0.6 = ユーザー受取率

-- 1. admin_post_yield関数の修正
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
    v_total_affiliate_profit DECIMAL(12,2);
    v_result JSON;
BEGIN
    -- 管理者権限チェック
    IF NOT EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text) THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;
    
    -- ユーザー利率計算（修正版）
    -- 正しい計算式: (日利率 - マージン率) × 0.6
    v_user_rate := (p_yield_rate - p_margin_rate) * 0.6;
    
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
    
    -- 紹介報酬計算（3段階）修正版
    -- 実効利率ベースで計算: (日利率 - マージン率) × 基準額 × 各レベル報酬率
    -- Level 1 (25%)
    INSERT INTO affiliate_reward (user_id, referral_user_id, date, level, reward_rate, base_profit, reward_amount, phase)
    SELECT 
        u1.user_id,
        udp.user_id,
        p_date,
        1,
        0.250,
        udp.base_amount * (p_yield_rate - p_margin_rate), -- 実効利率ベースの基準額
        udp.base_amount * (p_yield_rate - p_margin_rate) * 0.250,
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
        udp.base_amount * (p_yield_rate - p_margin_rate), -- 実効利率ベースの基準額
        udp.base_amount * (p_yield_rate - p_margin_rate) * 0.100,
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
        udp.base_amount * (p_yield_rate - p_margin_rate), -- 実効利率ベースの基準額
        udp.base_amount * (p_yield_rate - p_margin_rate) * 0.050,
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
    
    -- 統計計算
    SELECT 
        COUNT(*),
        SUM(base_amount),
        SUM(daily_profit)
    INTO v_total_users, v_total_base_amount, v_total_user_profit
    FROM user_daily_profit
    WHERE date = p_date;
    
    -- アフィリエイト報酬総額を計算
    SELECT 
        COALESCE(SUM(reward_amount), 0)
    INTO v_total_affiliate_profit
    FROM affiliate_reward
    WHERE date = p_date;
    
    -- 会社利益計算（修正版）
    -- 会社マージン30% + 実効利率の残り10%（プール金）
    v_total_company_profit := v_total_base_amount * p_margin_rate + v_total_base_amount * (p_yield_rate - p_margin_rate) * 0.1;
    
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

-- テストモード関数も同様に修正
CREATE OR REPLACE FUNCTION admin_post_yield_test_mode(
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
    
    -- テストモード: 実際の計算結果を返すが、データベースには保存しない
    SELECT 
        COUNT(*),
        SUM(ac.total_nft_count * 1100.00),
        SUM(ac.total_nft_count * 1100.00 * v_user_rate)
    INTO v_total_users, v_total_base_amount, v_total_user_profit
    FROM affiliate_cycle ac
    WHERE ac.total_nft_count > 0;
    
    -- アフィリエイト報酬総額を計算
    v_total_affiliate_profit := v_total_base_amount * (p_yield_rate - p_margin_rate) * 0.3;
    
    -- 会社利益計算
    v_total_company_profit := v_total_base_amount * p_margin_rate + v_total_base_amount * (p_yield_rate - p_margin_rate) * 0.1;
    
    v_result := json_build_object(
        'success', true,
        'test_mode', true,
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

COMMENT ON FUNCTION admin_post_yield IS '修正済み日利投稿関数: (日利率 - マージン率) × 0.6 = ユーザー受取率';
COMMENT ON FUNCTION admin_post_yield_test_mode IS '修正済みテストモード関数: 実際にデータベースに保存しない';