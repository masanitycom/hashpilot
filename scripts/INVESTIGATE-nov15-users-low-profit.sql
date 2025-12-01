-- ========================================
-- 11月15日運用開始ユーザーの調査
-- ========================================

-- STEP 1: 11月15日運用開始のユーザーを確認
SELECT 
    user_id,
    email,
    operation_start_date,
    has_approved_nft,
    total_nft_count
FROM users
WHERE operation_start_date = '2025-11-15'
ORDER BY user_id
LIMIT 10;

-- STEP 2: これらのユーザーの11月の日利履歴を確認
SELECT 
    udp.user_id,
    COUNT(*) as days_count,
    SUM(udp.daily_profit) as total_profit,
    MIN(udp.date) as first_date,
    MAX(udp.date) as last_date
FROM user_daily_profit udp
INNER JOIN users u ON udp.user_id = u.user_id
WHERE u.operation_start_date = '2025-11-15'
    AND udp.date >= '2025-11-01'
    AND udp.date <= '2025-11-30'
GROUP BY udp.user_id
ORDER BY udp.user_id
LIMIT 10;

-- STEP 3: 具体例：899254の日利詳細
SELECT 
    date,
    daily_profit,
    nft_count
FROM user_daily_profit
WHERE user_id = '899254'
    AND date >= '2025-11-01'
    AND date <= '2025-11-30'
ORDER BY date;

-- STEP 4: 11月15日以降の日利設定を確認
SELECT 
    date,
    yield_rate,
    margin_rate
FROM daily_yield_settings
WHERE date >= '2025-11-15'
    AND date <= '2025-11-30'
ORDER BY date;

-- STEP 5: affiliate_cycleの状態を確認
SELECT 
    ac.user_id,
    u.email,
    u.operation_start_date,
    ac.available_usdt,
    ac.cum_usdt,
    ac.total_nft_count
FROM affiliate_cycle ac
INNER JOIN users u ON ac.user_id = u.user_id
WHERE u.operation_start_date = '2025-11-15'
    AND ac.available_usdt < 10
ORDER BY ac.available_usdt DESC
LIMIT 20;

