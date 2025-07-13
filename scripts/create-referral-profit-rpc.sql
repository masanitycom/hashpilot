-- 緊急: 紹介報酬取得用RPC関数

CREATE OR REPLACE FUNCTION get_referral_profits(
    p_user_id TEXT,
    p_date DATE DEFAULT NULL,
    p_month_start DATE DEFAULT NULL,
    p_month_end DATE DEFAULT NULL
)
RETURNS TABLE (
    level INTEGER,
    yesterday_profit DECIMAL,
    monthly_profit DECIMAL,
    referral_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER  -- RLS制限を回避
AS $$
BEGIN
    -- デフォルト値設定
    IF p_date IS NULL THEN
        p_date := CURRENT_DATE - 1;
    END IF;
    
    IF p_month_start IS NULL THEN
        p_month_start := DATE_TRUNC('month', CURRENT_DATE);
    END IF;
    
    IF p_month_end IS NULL THEN
        p_month_end := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
    END IF;

    RETURN QUERY
    WITH referral_levels AS (
        -- Level1紹介者
        SELECT 
            1 as level,
            u1.user_id
        FROM users u1
        WHERE u1.referrer_user_id = p_user_id
        
        UNION ALL
        
        -- Level2紹介者
        SELECT 
            2 as level,
            u2.user_id
        FROM users u1
        JOIN users u2 ON u2.referrer_user_id = u1.user_id
        WHERE u1.referrer_user_id = p_user_id
        
        UNION ALL
        
        -- Level3紹介者
        SELECT 
            3 as level,
            u3.user_id
        FROM users u1
        JOIN users u2 ON u2.referrer_user_id = u1.user_id
        JOIN users u3 ON u3.referrer_user_id = u2.user_id
        WHERE u1.referrer_user_id = p_user_id
    ),
    profit_summary AS (
        SELECT 
            rl.level,
            COUNT(DISTINCT rl.user_id) as referral_count,
            -- 昨日の利益
            COALESCE(SUM(
                CASE WHEN udp.date = p_date 
                THEN udp.daily_profit::DECIMAL 
                ELSE 0 END
            ), 0) as yesterday_total,
            -- 今月の利益
            COALESCE(SUM(
                CASE WHEN udp.date >= p_month_start AND udp.date <= p_month_end 
                THEN udp.daily_profit::DECIMAL 
                ELSE 0 END
            ), 0) as monthly_total
        FROM referral_levels rl
        LEFT JOIN user_daily_profit udp ON rl.user_id = udp.user_id
        GROUP BY rl.level
    )
    SELECT 
        ps.level,
        ps.yesterday_total * CASE 
            WHEN ps.level = 1 THEN 0.20
            WHEN ps.level = 2 THEN 0.10
            WHEN ps.level = 3 THEN 0.05
            ELSE 0
        END as yesterday_profit,
        ps.monthly_total * CASE 
            WHEN ps.level = 1 THEN 0.20
            WHEN ps.level = 2 THEN 0.10
            WHEN ps.level = 3 THEN 0.05
            ELSE 0
        END as monthly_profit,
        ps.referral_count
    FROM profit_summary ps
    ORDER BY ps.level;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION get_referral_profits(TEXT, DATE, DATE, DATE) TO authenticated;

-- テスト
SELECT * FROM get_referral_profits('7A9637');