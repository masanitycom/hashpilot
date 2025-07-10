-- 特定ユーザーの利益データ確認

-- 1. user_daily_profitテーブルの7/9データ（サンプル）
SELECT 
    'Sample profit data for 2025-07-09' as info,
    user_id,
    date,
    daily_profit,
    base_amount,
    yield_rate,
    user_rate
FROM user_daily_profit 
WHERE date = '2025-07-09'
ORDER BY daily_profit DESC
LIMIT 10;

-- 2. ログインユーザーのIDを特定する必要があります
-- Supabase AuthのユーザーIDとusersテーブルのuser_idのマッピング確認
SELECT 
    'Users table mapping' as info,
    id as auth_user_id,
    user_id,
    email,
    total_purchases
FROM users 
WHERE total_purchases > 0
ORDER BY total_purchases DESC
LIMIT 10;

-- 3. affiliate_cycleとuser_daily_profitの結合確認
SELECT 
    'Cycle to Profit mapping' as info,
    ac.user_id,
    ac.total_nft_count,
    ac.cum_usdt,
    udp.date,
    udp.daily_profit
FROM affiliate_cycle ac
LEFT JOIN user_daily_profit udp ON ac.user_id = udp.user_id AND udp.date = '2025-07-09'
WHERE ac.total_nft_count > 0
ORDER BY ac.total_nft_count DESC
LIMIT 10;

-- 4. 特定のメールアドレスのユーザー確認（例：basarasystems@gmail.com）
SELECT 
    'Specific user check' as info,
    u.id as auth_user_id,
    u.user_id,
    u.email,
    u.total_purchases,
    ac.total_nft_count,
    udp.daily_profit
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id AND udp.date = '2025-07-09'
WHERE u.email IN ('basarasystems@gmail.com', 'admin@hashpilot.com')
   OR u.total_purchases > 5000
ORDER BY u.total_purchases DESC;