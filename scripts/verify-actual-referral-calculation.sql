-- ========================================
-- 🔍 実際の紹介報酬計算の検証
-- 管理画面で設定した日利を使用
-- ========================================

-- STEP 1: 7A9637の紹介構造確認
WITH referral_structure AS (
    -- Level1 (直接紹介者)
    SELECT user_id, 1 as level, total_purchases
    FROM users 
    WHERE referrer_user_id = '7A9637'
    
    UNION
    
    -- Level2 (2段目紹介者)
    SELECT u2.user_id, 2 as level, u2.total_purchases
    FROM users u1
    JOIN users u2 ON u1.user_id = u2.referrer_user_id
    WHERE u1.referrer_user_id = '7A9637'
    
    UNION
    
    -- Level3 (3段目紹介者)
    SELECT u3.user_id, 3 as level, u3.total_purchases
    FROM users u1
    JOIN users u2 ON u1.user_id = u2.referrer_user_id
    JOIN users u3 ON u2.user_id = u3.referrer_user_id
    WHERE u1.referrer_user_id = '7A9637'
)
SELECT 
    '=== 🎯 7A9637紹介構造 ===' as structure_check,
    level,
    COUNT(*) as user_count,
    SUM(total_purchases) as total_investment,
    array_agg(user_id ORDER BY user_id) as user_ids
FROM referral_structure
GROUP BY level
ORDER BY level;

-- STEP 2: 実際の日利設定確認（7月全体）
SELECT 
    '=== 📈 7月の日利設定 ===' as yield_settings,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    (yield_rate * 100) as yield_percent,
    (user_rate * 100) as user_percent
FROM daily_yield_log
WHERE date >= '2025-07-01' AND date <= '2025-07-31'
ORDER BY date;

-- STEP 3: 各紹介者の実際の利益データ確認
WITH referral_users AS (
    -- Level1
    SELECT user_id, 1 as level FROM users WHERE referrer_user_id = '7A9637'
    UNION
    -- Level2
    SELECT u2.user_id, 2 as level
    FROM users u1
    JOIN users u2 ON u1.user_id = u2.referrer_user_id
    WHERE u1.referrer_user_id = '7A9637'
    UNION
    -- Level3
    SELECT u3.user_id, 3 as level
    FROM users u1
    JOIN users u2 ON u1.user_id = u2.referrer_user_id
    JOIN users u3 ON u2.user_id = u3.referrer_user_id
    WHERE u1.referrer_user_id = '7A9637'
)
SELECT 
    '=== 💰 紹介者の実際の利益データ ===' as profit_data,
    ru.level,
    ru.user_id,
    udp.date,
    udp.daily_profit,
    udp.yield_rate,
    udp.user_rate,
    u.total_purchases,
    ac.total_nft_count
FROM referral_users ru
JOIN users u ON ru.user_id = u.user_id
LEFT JOIN affiliate_cycle ac ON ru.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON ru.user_id = udp.user_id
WHERE udp.date >= '2025-07-01' AND udp.date <= '2025-07-31'
ORDER BY ru.level, ru.user_id, udp.date;

-- STEP 4: レベル別利益集計（正確な計算）
WITH referral_users AS (
    -- Level1
    SELECT user_id, 1 as level FROM users WHERE referrer_user_id = '7A9637'
    UNION
    -- Level2
    SELECT u2.user_id, 2 as level
    FROM users u1
    JOIN users u2 ON u1.user_id = u2.referrer_user_id
    WHERE u1.referrer_user_id = '7A9637'
    UNION
    -- Level3
    SELECT u3.user_id, 3 as level
    FROM users u1
    JOIN users u2 ON u1.user_id = u2.referrer_user_id
    JOIN users u3 ON u2.user_id = u3.referrer_user_id
    WHERE u1.referrer_user_id = '7A9637'
),
profit_summary AS (
    SELECT 
        ru.level,
        ru.user_id,
        udp.date,
        udp.daily_profit
    FROM referral_users ru
    JOIN user_daily_profit udp ON ru.user_id = udp.user_id
    WHERE udp.date >= '2025-07-01' AND udp.date <= '2025-07-31'
)
SELECT 
    '=== 📊 レベル別利益集計 ===' as level_summary,
    level,
    COUNT(DISTINCT user_id) as user_count,
    COUNT(*) as total_profit_records,
    SUM(daily_profit) as total_profit,
    AVG(daily_profit) as avg_daily_profit,
    -- 昨日（7/16）の利益
    SUM(CASE WHEN date = '2025-07-16' THEN daily_profit ELSE 0 END) as yesterday_profit,
    -- 今月累計利益
    SUM(daily_profit) as monthly_profit
FROM profit_summary
GROUP BY level
ORDER BY level;

-- STEP 5: 正確な紹介報酬計算
WITH level_profits AS (
    SELECT 
        1 as level,
        20.0 as reward_rate,
        SUM(CASE WHEN udp.date = '2025-07-16' THEN udp.daily_profit ELSE 0 END) as yesterday_profit,
        SUM(udp.daily_profit) as monthly_profit
    FROM users u1
    JOIN user_daily_profit udp ON u1.user_id = udp.user_id
    WHERE u1.referrer_user_id = '7A9637'
      AND udp.date >= '2025-07-01' AND udp.date <= '2025-07-31'
    
    UNION
    
    SELECT 
        2 as level,
        10.0 as reward_rate,
        SUM(CASE WHEN udp.date = '2025-07-16' THEN udp.daily_profit ELSE 0 END) as yesterday_profit,
        SUM(udp.daily_profit) as monthly_profit
    FROM users u1
    JOIN users u2 ON u1.user_id = u2.referrer_user_id
    JOIN user_daily_profit udp ON u2.user_id = udp.user_id
    WHERE u1.referrer_user_id = '7A9637'
      AND udp.date >= '2025-07-01' AND udp.date <= '2025-07-31'
      
    UNION
    
    SELECT 
        3 as level,
        5.0 as reward_rate,
        SUM(CASE WHEN udp.date = '2025-07-16' THEN udp.daily_profit ELSE 0 END) as yesterday_profit,
        SUM(udp.daily_profit) as monthly_profit
    FROM users u1
    JOIN users u2 ON u1.user_id = u2.referrer_user_id
    JOIN users u3 ON u2.user_id = u3.referrer_user_id
    JOIN user_daily_profit udp ON u3.user_id = udp.user_id
    WHERE u1.referrer_user_id = '7A9637'
      AND udp.date >= '2025-07-01' AND udp.date <= '2025-07-31'
)
SELECT 
    '=== 🎯 正確な紹介報酬計算 ===' as reward_calculation,
    level,
    reward_rate as reward_rate_percent,
    yesterday_profit as level_yesterday_profit,
    monthly_profit as level_monthly_profit,
    ROUND(yesterday_profit * reward_rate / 100, 3) as yesterday_reward,
    ROUND(monthly_profit * reward_rate / 100, 3) as monthly_reward
FROM level_profits
ORDER BY level;

-- STEP 6: 総合計
WITH level_profits AS (
    SELECT 
        1 as level, 20.0 as reward_rate,
        SUM(CASE WHEN udp.date = '2025-07-16' THEN udp.daily_profit ELSE 0 END) as yesterday_profit,
        SUM(udp.daily_profit) as monthly_profit
    FROM users u1
    JOIN user_daily_profit udp ON u1.user_id = udp.user_id
    WHERE u1.referrer_user_id = '7A9637'
      AND udp.date >= '2025-07-01' AND udp.date <= '2025-07-31'
    UNION
    SELECT 
        2 as level, 10.0 as reward_rate,
        SUM(CASE WHEN udp.date = '2025-07-16' THEN udp.daily_profit ELSE 0 END) as yesterday_profit,
        SUM(udp.daily_profit) as monthly_profit
    FROM users u1
    JOIN users u2 ON u1.user_id = u2.referrer_user_id
    JOIN user_daily_profit udp ON u2.user_id = udp.user_id
    WHERE u1.referrer_user_id = '7A9637'
      AND udp.date >= '2025-07-01' AND udp.date <= '2025-07-31'
    UNION
    SELECT 
        3 as level, 5.0 as reward_rate,
        SUM(CASE WHEN udp.date = '2025-07-16' THEN udp.daily_profit ELSE 0 END) as yesterday_profit,
        SUM(udp.daily_profit) as monthly_profit
    FROM users u1
    JOIN users u2 ON u1.user_id = u2.referrer_user_id
    JOIN users u3 ON u2.user_id = u3.referrer_user_id
    JOIN user_daily_profit udp ON u3.user_id = udp.user_id
    WHERE u1.referrer_user_id = '7A9637'
      AND udp.date >= '2025-07-01' AND udp.date <= '2025-07-31'
)
SELECT 
    '=== 🏆 最終合計 ===' as final_total,
    SUM(ROUND(yesterday_profit * reward_rate / 100, 3)) as total_yesterday_reward,
    SUM(ROUND(monthly_profit * reward_rate / 100, 3)) as total_monthly_reward,
    SUM(yesterday_profit) as total_referral_yesterday_profit,
    SUM(monthly_profit) as total_referral_monthly_profit
FROM level_profits;