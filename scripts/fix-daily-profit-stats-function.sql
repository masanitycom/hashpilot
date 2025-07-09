-- Fix the get_user_daily_profit_stats function to handle interval parameter correctly
DROP FUNCTION IF EXISTS get_user_daily_profit_stats(text, integer);

CREATE OR REPLACE FUNCTION get_user_daily_profit_stats(
    p_user_id TEXT,
    p_days INTEGER DEFAULT 30
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
    daily_profits JSON;
    summary_data JSON;
    total_profit DECIMAL := 0;
    total_referral DECIMAL := 0;
    total_rewards DECIMAL := 0;
    avg_daily_profit DECIMAL := 0;
    days_count INTEGER := 0;
BEGIN
    -- Get daily profit data for the specified period
    WITH daily_data AS (
        SELECT 
            udp.profit_date::date as date,
            COALESCE(dyl.yield_rate, 0) as yield_rate,
            COALESCE(udp.daily_profit, 0) as daily_profit,
            COALESCE(udp.referral_reward, 0) as referral_reward,
            COALESCE(udp.daily_profit, 0) + COALESCE(udp.referral_reward, 0) as total_reward
        FROM user_daily_profit udp
        LEFT JOIN daily_yield_log dyl ON udp.profit_date::date = dyl.yield_date
        WHERE udp.user_id = p_user_id
        AND udp.profit_date >= CURRENT_DATE - INTERVAL '1 day' * p_days
        ORDER BY udp.profit_date DESC
    )
    SELECT json_agg(
        json_build_object(
            'date', date,
            'yield_rate', yield_rate,
            'daily_profit', daily_profit,
            'referral_reward', referral_reward,
            'total_reward', total_reward
        )
    ) INTO daily_profits
    FROM daily_data;

    -- Calculate summary statistics
    SELECT 
        COALESCE(SUM(udp.daily_profit), 0),
        COALESCE(SUM(udp.referral_reward), 0),
        COUNT(*)
    INTO total_profit, total_referral, days_count
    FROM user_daily_profit udp
    WHERE udp.user_id = p_user_id
    AND udp.profit_date >= CURRENT_DATE - INTERVAL '1 day' * p_days;

    total_rewards := total_profit + total_referral;
    avg_daily_profit := CASE WHEN days_count > 0 THEN total_profit / days_count ELSE 0 END;

    -- Build summary object
    summary_data := json_build_object(
        'total_days', days_count,
        'total_profit', total_profit,
        'total_referral', total_referral,
        'total_rewards', total_rewards,
        'avg_daily_profit', avg_daily_profit
    );

    -- Build final result
    result := json_build_object(
        'daily_profits', COALESCE(daily_profits, '[]'::json),
        'summary', summary_data
    );

    RETURN result;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_user_daily_profit_stats(TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_daily_profit_stats(TEXT, INTEGER) TO anon;
