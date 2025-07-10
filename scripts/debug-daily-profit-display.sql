-- 日利表示のデバッグ

-- 1. 現在の日付と時刻を確認
SELECT 
    'Current date/time' as info,
    CURRENT_DATE as today,
    CURRENT_DATE - INTERVAL '1 day' as yesterday,
    NOW() as current_timestamp,
    NOW() AT TIME ZONE 'Asia/Tokyo' as japan_time;

-- 2. user_daily_profitテーブルの最新データ
SELECT 
    'Latest daily profit data' as info,
    user_id,
    date,
    daily_profit,
    created_at,
    date = CURRENT_DATE - INTERVAL '1 day' as is_yesterday
FROM user_daily_profit
WHERE user_id = '7A9637'
ORDER BY date DESC
LIMIT 5;

-- 3. 日付形式の確認
SELECT 
    'Date format check' as info,
    date,
    date::TEXT as date_text,
    TO_CHAR(date, 'YYYY-MM-DD') as formatted_date
FROM user_daily_profit
WHERE user_id = '7A9637'
ORDER BY date DESC
LIMIT 1;

-- 4. JavaScriptで使用される日付との比較
SELECT 
    'JavaScript date comparison' as info,
    date,
    date = '2025-07-09'::DATE as matches_2025_07_09,
    date = (CURRENT_DATE - INTERVAL '1 day') as matches_yesterday
FROM user_daily_profit
WHERE user_id = '7A9637'
ORDER BY date DESC
LIMIT 1;

-- 5. 今月の累積利益の確認
SELECT 
    'Monthly accumulation' as info,
    user_id,
    COUNT(*) as days_with_profit,
    SUM(daily_profit) as total_profit,
    MIN(date) as first_date,
    MAX(date) as last_date
FROM user_daily_profit
WHERE user_id = '7A9637'
AND date >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY user_id;