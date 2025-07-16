-- 🚨 簡単な修正：直接データを取得
-- 2025年7月17日

-- 1. 既存の関数を削除
DROP FUNCTION IF EXISTS get_referral_profits(text,date,date,date);

-- 2. シンプルな関数を作成
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
    -- 現在のデータベース構造では、紹介報酬は user_daily_profit.referral_profit にまとめて格納
    -- Level1として全紹介報酬を返す
    SELECT 
        1 as level,
        COALESCE(SUM(CASE WHEN udp.date = p_date THEN udp.referral_profit ELSE 0 END), 0) as yesterday_profit,
        COALESCE(SUM(CASE WHEN udp.date >= p_month_start AND udp.date <= p_month_end THEN udp.referral_profit ELSE 0 END), 0) as monthly_profit
    FROM user_daily_profit udp
    WHERE udp.user_id = p_user_id
    AND udp.date >= p_month_start
    AND udp.date <= p_date
    
    UNION ALL
    
    -- Level2とLevel3は0を返す（現在のDB構造では分離されていない）
    SELECT 2 as level, 0::NUMERIC as yesterday_profit, 0::NUMERIC as monthly_profit
    
    UNION ALL
    
    SELECT 3 as level, 0::NUMERIC as yesterday_profit, 0::NUMERIC as monthly_profit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. テスト実行
SELECT * FROM get_referral_profits('7A9637', '2025-07-16', '2025-07-01', '2025-07-31');

-- 4. 実際のデータ確認
SELECT 
    'actual_data' as check_type,
    date,
    referral_profit,
    personal_profit,
    daily_profit
FROM user_daily_profit 
WHERE user_id = '7A9637'
AND date >= '2025-07-01'
ORDER BY date DESC;