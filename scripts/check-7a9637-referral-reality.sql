-- 7A9637の紹介報酬の実態を確認

-- 1. 7A9637の直接紹介者（Level1）の実際の利益
SELECT 
    '=== 7A9637のLevel1紹介者の実際の利益 ===' as info,
    u.user_id,
    u.email,
    SUM(udp.daily_profit::DECIMAL) as total_profit,
    COUNT(udp.date) as profit_days,
    MIN(udp.date) as first_profit_date,
    MAX(udp.date) as latest_profit_date
FROM users u
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.referrer_user_id = '7A9637'
GROUP BY u.user_id, u.email
ORDER BY total_profit DESC;

-- 2. Level2紹介者の実際の利益
SELECT 
    '=== 7A9637のLevel2紹介者の実際の利益 ===' as info,
    u2.user_id,
    u2.email,
    u1.user_id as level1_referrer,
    COALESCE(SUM(udp.daily_profit::DECIMAL), 0) as total_profit,
    COUNT(udp.date) as profit_days
FROM users u1
JOIN users u2 ON u2.referrer_user_id = u1.user_id
LEFT JOIN user_daily_profit udp ON u2.user_id = udp.user_id
WHERE u1.referrer_user_id = '7A9637'
GROUP BY u2.user_id, u2.email, u1.user_id
ORDER BY total_profit DESC;

-- 3. Level3紹介者の実際の利益
SELECT 
    '=== 7A9637のLevel3紹介者の実際の利益 ===' as info,
    u3.user_id,
    u3.email,
    u2.user_id as level2_referrer,
    u1.user_id as level1_referrer,
    COALESCE(SUM(udp.daily_profit::DECIMAL), 0) as total_profit,
    COUNT(udp.date) as profit_days
FROM users u1
JOIN users u2 ON u2.referrer_user_id = u1.user_id
JOIN users u3 ON u3.referrer_user_id = u2.user_id
LEFT JOIN user_daily_profit udp ON u3.user_id = udp.user_id
WHERE u1.referrer_user_id = '7A9637'
GROUP BY u3.user_id, u3.email, u2.user_id, u1.user_id
ORDER BY total_profit DESC;

-- 4. 正しい紹介報酬計算
WITH level_profits AS (
    -- Level1の利益
    SELECT 
        1 as level,
        u.user_id,
        COALESCE(SUM(udp.daily_profit::DECIMAL), 0) as total_profit
    FROM users u
    LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
    WHERE u.referrer_user_id = '7A9637'
    GROUP BY u.user_id
    
    UNION ALL
    
    -- Level2の利益
    SELECT 
        2 as level,
        u2.user_id,
        COALESCE(SUM(udp.daily_profit::DECIMAL), 0) as total_profit
    FROM users u1
    JOIN users u2 ON u2.referrer_user_id = u1.user_id
    LEFT JOIN user_daily_profit udp ON u2.user_id = udp.user_id
    WHERE u1.referrer_user_id = '7A9637'
    GROUP BY u2.user_id
    
    UNION ALL
    
    -- Level3の利益
    SELECT 
        3 as level,
        u3.user_id,
        COALESCE(SUM(udp.daily_profit::DECIMAL), 0) as total_profit
    FROM users u1
    JOIN users u2 ON u2.referrer_user_id = u1.user_id
    JOIN users u3 ON u3.referrer_user_id = u2.user_id
    LEFT JOIN user_daily_profit udp ON u3.user_id = udp.user_id
    WHERE u1.referrer_user_id = '7A9637'
    GROUP BY u3.user_id
)
SELECT 
    '=== 7A9637の正しい紹介報酬計算 ===' as calculation,
    level,
    COUNT(*) as referral_count,
    SUM(total_profit) as total_referral_profit,
    CASE 
        WHEN level = 1 THEN SUM(total_profit) * 0.20
        WHEN level = 2 THEN SUM(total_profit) * 0.10
        WHEN level = 3 THEN SUM(total_profit) * 0.05
    END as should_receive,
    CASE 
        WHEN level = 1 THEN '20%'
        WHEN level = 2 THEN '10%'
        WHEN level = 3 THEN '5%'
    END as rate
FROM level_profits
WHERE total_profit > 0
GROUP BY level
ORDER BY level;