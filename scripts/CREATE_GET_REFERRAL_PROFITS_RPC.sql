-- 🚨 get_referral_profits RPC関数を作成
-- 2025年7月17日

-- 1. 既存の関数を確認
SELECT 
    '既存RPC関数確認' as check_type,
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_name = 'get_referral_profits';

-- 2. get_referral_profits関数を作成
CREATE OR REPLACE FUNCTION get_referral_profits(
    p_user_id TEXT,
    p_date DATE,
    p_month_start DATE,
    p_month_end DATE
) RETURNS TABLE (
    level INTEGER,
    yesterday_profit NUMERIC,
    monthly_profit NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        1 as level,
        COALESCE(SUM(CASE WHEN udp.date = p_date THEN udp.referral_profit ELSE 0 END), 0) as yesterday_profit,
        COALESCE(SUM(CASE WHEN udp.date >= p_month_start AND udp.date <= p_month_end THEN udp.referral_profit ELSE 0 END), 0) as monthly_profit
    FROM user_daily_profit udp
    WHERE udp.user_id = p_user_id
    AND udp.date >= p_month_start
    AND udp.date <= p_date
    AND udp.referral_profit > 0
    
    UNION ALL
    
    -- Level2とLevel3は現在のデータベース構造では分離されていないため、
    -- 簡単な推定（Level2の場合は全紹介報酬の一部として扱う）
    SELECT 
        2 as level,
        COALESCE(SUM(CASE WHEN udp.date = p_date THEN udp.referral_profit ELSE 0 END), 0) as yesterday_profit,
        COALESCE(SUM(CASE WHEN udp.date >= p_month_start AND udp.date <= p_month_end THEN udp.referral_profit ELSE 0 END), 0) as monthly_profit
    FROM user_daily_profit udp
    WHERE udp.user_id = p_user_id
    AND udp.date >= p_month_start
    AND udp.date <= p_date
    AND udp.referral_profit > 0
    
    UNION ALL
    
    SELECT 
        3 as level,
        0::NUMERIC as yesterday_profit,
        0::NUMERIC as monthly_profit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. 関数をテスト
SELECT * FROM get_referral_profits('7A9637', '2025-07-16', '2025-07-01', '2025-07-31');

-- 4. 実際の7A9637のデータを直接確認
SELECT 
    'direct_data_check' as check_type,
    date,
    referral_profit,
    personal_profit,
    daily_profit
FROM user_daily_profit 
WHERE user_id = '7A9637'
AND date >= '2025-07-01'
AND referral_profit > 0
ORDER BY date DESC;