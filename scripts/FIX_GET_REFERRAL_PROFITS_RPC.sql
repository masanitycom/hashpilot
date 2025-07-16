-- 🚨 get_referral_profits RPC関数を修正
-- 2025年7月17日

-- 1. 既存の関数を削除
DROP FUNCTION IF EXISTS get_referral_profits(text,date,date,date);

-- 2. 新しい関数を作成
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
    -- Level1紹介報酬（実際の紹介報酬データを使用）
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
    
    -- Level2紹介報酬（実際の紹介報酬データを使用）
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
    
    -- Level3紹介報酬（現在は0）
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