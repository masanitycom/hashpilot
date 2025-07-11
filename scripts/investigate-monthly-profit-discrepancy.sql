-- 月利表示不具合の調査スクリプト
-- 2000ドル保有ユーザーの日利データと月利表示の差異を調査

-- 1. 2000ドル保有で紹介者なしのユーザーを特定
SELECT '=== 2000ドル保有ユーザー一覧 ===' as section;
SELECT 
    user_id, 
    email, 
    total_purchases, 
    referrer_user_id,
    created_at
FROM users 
WHERE total_purchases = 2000 
AND (referrer_user_id IS NULL OR referrer_user_id = '' OR referrer_user_id = 'null')
ORDER BY created_at DESC
LIMIT 5;

-- 2. 1000ドル保有で紹介者ありのユーザーも確認
SELECT '=== 1000ドル保有ユーザー一覧 ===' as section;
SELECT 
    user_id, 
    email, 
    total_purchases, 
    referrer_user_id,
    created_at
FROM users 
WHERE total_purchases = 1000 
AND referrer_user_id IS NOT NULL 
AND referrer_user_id != '' 
AND referrer_user_id != 'null'
ORDER BY created_at DESC
LIMIT 5;

-- 3. 特定ユーザーの7月の日利データを詳細調査（2000ドルユーザーの例）
SELECT '=== 2000ドルユーザーの7月日利データ ===' as section;
WITH target_user AS (
    SELECT user_id 
    FROM users 
    WHERE total_purchases = 2000 
    AND (referrer_user_id IS NULL OR referrer_user_id = '' OR referrer_user_id = 'null')
    LIMIT 1
)
SELECT 
    u.user_id,
    u.email,
    u.total_purchases,
    udp.date,
    udp.daily_profit,
    (udp.daily_profit::DECIMAL / u.total_purchases * 100) as calculated_rate
FROM users u
JOIN user_daily_profit udp ON u.user_id = udp.user_id
JOIN target_user t ON u.user_id = t.user_id
WHERE udp.date >= '2025-07-01' 
AND udp.date <= '2025-07-31'
ORDER BY udp.date DESC;

-- 4. 同じユーザーの月利合計計算
SELECT '=== 月利合計の計算確認 ===' as section;
WITH target_user AS (
    SELECT user_id 
    FROM users 
    WHERE total_purchases = 2000 
    AND (referrer_user_id IS NULL OR referrer_user_id = '' OR referrer_user_id = 'null')
    LIMIT 1
),
monthly_calculation AS (
    SELECT 
        u.user_id,
        u.email,
        u.total_purchases,
        COUNT(udp.date) as profit_days,
        SUM(udp.daily_profit::DECIMAL) as total_monthly_profit,
        AVG(udp.daily_profit::DECIMAL) as avg_daily_profit,
        (SUM(udp.daily_profit::DECIMAL) / u.total_purchases * 100) as total_monthly_rate
    FROM users u
    JOIN user_daily_profit udp ON u.user_id = udp.user_id
    JOIN target_user t ON u.user_id = t.user_id
    WHERE udp.date >= '2025-07-01' 
    AND udp.date <= '2025-07-31'
    GROUP BY u.user_id, u.email, u.total_purchases
)
SELECT * FROM monthly_calculation;

-- 5. 他のユーザーとの比較（1000ドルユーザー）
SELECT '=== 1000ドルユーザーの7月データ比較 ===' as section;
WITH target_user AS (
    SELECT user_id 
    FROM users 
    WHERE total_purchases = 1000 
    AND referrer_user_id IS NOT NULL 
    AND referrer_user_id != '' 
    AND referrer_user_id != 'null'
    LIMIT 1
)
SELECT 
    u.user_id,
    u.email,
    u.total_purchases,
    COUNT(udp.date) as profit_days,
    SUM(udp.daily_profit::DECIMAL) as total_monthly_profit,
    AVG(udp.daily_profit::DECIMAL) as avg_daily_profit,
    (SUM(udp.daily_profit::DECIMAL) / u.total_purchases * 100) as total_monthly_rate
FROM users u
JOIN user_daily_profit udp ON u.user_id = udp.user_id
JOIN target_user t ON u.user_id = t.user_id
WHERE udp.date >= '2025-07-01' 
AND udp.date <= '2025-07-31'
GROUP BY u.user_id, u.email, u.total_purchases;

-- 6. 同じ金額($38.32付近)になっているユーザーを検索
SELECT '=== $38.32付近の月利を持つユーザー ===' as section;
WITH monthly_profits AS (
    SELECT 
        u.user_id,
        u.email,
        u.total_purchases,
        SUM(udp.daily_profit::DECIMAL) as total_monthly_profit
    FROM users u
    JOIN user_daily_profit udp ON u.user_id = udp.user_id
    WHERE udp.date >= '2025-07-01' 
    AND udp.date <= '2025-07-31'
    GROUP BY u.user_id, u.email, u.total_purchases
)
SELECT *
FROM monthly_profits
WHERE total_monthly_profit BETWEEN 38.0 AND 39.0
ORDER BY total_monthly_profit DESC;

-- 7. 日利データの異常値チェック
SELECT '=== 異常な日利データの検出 ===' as section;
SELECT 
    u.user_id,
    u.email,
    u.total_purchases,
    udp.date,
    udp.daily_profit,
    (udp.daily_profit::DECIMAL / u.total_purchases * 100) as rate_percent
FROM users u
JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE udp.date >= '2025-07-01' 
AND udp.date <= '2025-07-31'
AND (
    udp.daily_profit::DECIMAL < 0 OR  -- マイナス利益
    udp.daily_profit::DECIMAL > u.total_purchases * 0.05 OR  -- 5%超の異常に高い利益
    udp.daily_profit::DECIMAL = 0  -- ゼロ利益
)
ORDER BY udp.date DESC, udp.daily_profit DESC;