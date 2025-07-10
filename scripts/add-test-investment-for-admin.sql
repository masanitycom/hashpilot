-- basarasystems@gmail.comユーザーにテスト投資データを追加

-- 1. 現在の状況確認
SELECT 
    'Current admin user status' as info,
    id,
    user_id,
    email,
    total_purchases
FROM users 
WHERE email = 'basarasystems@gmail.com';

-- 2. テスト用にaffiliate_cycleにデータを追加（1 NFT = $1,100）
INSERT INTO affiliate_cycle (
    user_id,
    phase,
    total_nft_count,
    cum_usdt,
    cycle_start_date,
    last_updated
)
VALUES (
    '6BCCED',  -- basarasystems@gmail.comのuser_id
    'USDT',
    1,         -- 1 NFT
    1100,      -- $1,100
    '2025-07-08',
    NOW()
)
ON CONFLICT (user_id) DO UPDATE SET
    total_nft_count = 1,
    cum_usdt = 1100,
    last_updated = NOW();

-- 3. usersテーブルのtotal_purchasesも更新
UPDATE users 
SET total_purchases = 1100
WHERE user_id = '6BCCED';

-- 4. 昨日（7/9）の利益データを生成
INSERT INTO user_daily_profit (
    user_id,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    created_at
)
VALUES (
    '6BCCED',
    '2025-07-09',
    7.39,      -- $1,100 × 0.672% = $7.39
    0.016,
    0.00672,
    1100,
    'USDT',
    NOW()
)
ON CONFLICT (user_id, date) DO UPDATE SET
    daily_profit = 7.39,
    base_amount = 1100;

-- 5. 結果確認
SELECT 
    'Updated admin user data' as info,
    u.user_id,
    u.email,
    u.total_purchases,
    ac.total_nft_count,
    udp.date,
    udp.daily_profit
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id AND udp.date = '2025-07-09'
WHERE u.email = 'basarasystems@gmail.com';