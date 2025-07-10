-- 日利データの型と値を詳細調査

-- 1. user_daily_profitテーブルの構造確認
SELECT '=== user_daily_profit テーブル構造 ===' as section;
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'user_daily_profit' 
ORDER BY ordinal_position;

-- 2. 最近の日利データのサンプル（生の値）
SELECT '=== 最近の日利データサンプル（生の値） ===' as section;
SELECT 
    user_id,
    date,
    daily_profit,
    daily_profit::text as daily_profit_text,
    daily_profit::numeric as daily_profit_numeric,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    created_at
FROM user_daily_profit 
WHERE date >= '2025-07-01'
ORDER BY date DESC, user_id
LIMIT 20;

-- 3. 日利データの統計
SELECT '=== 日利データの統計 ===' as section;
SELECT 
    date,
    COUNT(*) as user_count,
    MIN(daily_profit::numeric) as min_profit,
    MAX(daily_profit::numeric) as max_profit,
    AVG(daily_profit::numeric) as avg_profit,
    SUM(daily_profit::numeric) as total_profit
FROM user_daily_profit 
WHERE date >= '2025-07-01'
GROUP BY date
ORDER BY date DESC;

-- 4. 具体的なユーザーの7月データ（投資額別）
SELECT '=== 投資額別の日利データ比較 ===' as section;
WITH user_investments AS (
    SELECT 
        u.user_id,
        u.total_purchases,
        CASE 
            WHEN u.total_purchases >= 2000 THEN '2000+'
            WHEN u.total_purchases >= 1000 THEN '1000-1999'
            WHEN u.total_purchases >= 500 THEN '500-999'
            ELSE 'Under 500'
        END as investment_tier
    FROM users u
    WHERE u.total_purchases > 0
)
SELECT 
    ui.investment_tier,
    ui.user_id,
    ui.total_purchases,
    udp.date,
    udp.daily_profit,
    udp.daily_profit::numeric as numeric_profit,
    (udp.daily_profit::numeric / ui.total_purchases * 100) as profit_rate_percent
FROM user_investments ui
JOIN user_daily_profit udp ON ui.user_id = udp.user_id
WHERE udp.date >= '2025-07-06'
AND udp.date <= '2025-07-10'
ORDER BY ui.investment_tier, ui.user_id, udp.date DESC
LIMIT 50;

-- 5. 月利合計の確認（2000ドルユーザー）
SELECT '=== 2000ドルユーザーの月利合計確認 ===' as section;
SELECT 
    u.user_id,
    u.email,
    u.total_purchases,
    COUNT(udp.date) as profit_days,
    ARRAY_AGG(udp.date ORDER BY udp.date) as dates,
    ARRAY_AGG(udp.daily_profit::numeric ORDER BY udp.date) as daily_profits,
    SUM(udp.daily_profit::numeric) as total_monthly_profit
FROM users u
JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.total_purchases = 2000
AND udp.date >= '2025-07-01'
GROUP BY u.user_id, u.email, u.total_purchases
ORDER BY total_monthly_profit DESC
LIMIT 5;

-- 6. データ型変換テスト
SELECT '=== データ型変換テスト ===' as section;
SELECT 
    daily_profit,
    daily_profit::text as as_text,
    daily_profit::numeric as as_numeric,
    daily_profit::float as as_float,
    daily_profit::decimal as as_decimal
FROM user_daily_profit 
WHERE date >= '2025-07-01'
LIMIT 10;