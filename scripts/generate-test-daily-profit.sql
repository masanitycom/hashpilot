-- テスト用日利データの生成
-- 本番環境では慎重に使用してください

-- 1. 現在の日利データの状況を確認
SELECT 
    'Current daily profit data' as info,
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as unique_users,
    MIN(date) as earliest_date,
    MAX(date) as latest_date
FROM user_daily_profit;

-- 2. affiliate_cycleのユーザーを確認
SELECT 
    'Users with NFTs' as info,
    user_id,
    total_nft_count,
    phase,
    cum_usdt,
    available_usdt
FROM affiliate_cycle
WHERE total_nft_count > 0
ORDER BY total_nft_count DESC
LIMIT 10;

-- 3. 昨日（2025-07-09）の日利データを生成
-- 実際に実行する場合は、以下のコメントを外してください
/*
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
SELECT 
    ac.user_id,
    '2025-07-09'::DATE,
    ac.total_nft_count * 1100 * 0.00672,  -- 1.6% * (1-30%) * 0.6 = 0.672%
    0.016,  -- 1.6%
    0.00672,  -- 0.672%
    ac.total_nft_count * 1100,
    ac.phase,
    NOW()
FROM affiliate_cycle ac
WHERE ac.total_nft_count > 0
ON CONFLICT (user_id, date) DO UPDATE SET
    daily_profit = EXCLUDED.daily_profit,
    yield_rate = EXCLUDED.yield_rate,
    user_rate = EXCLUDED.user_rate,
    base_amount = EXCLUDED.base_amount,
    phase = EXCLUDED.phase,
    created_at = NOW();
*/

-- 4. 過去7日間のテストデータを生成（必要に応じて）
/*
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
SELECT 
    ac.user_id,
    generate_series::DATE,
    ac.total_nft_count * 1100 * (0.005 + RANDOM() * 0.015),  -- 0.5% ~ 2.0%のランダム
    0.01 + RANDOM() * 0.01,  -- 1% ~ 2%のランダム
    (0.01 + RANDOM() * 0.01) * 0.7 * 0.6,  -- ユーザー利率
    ac.total_nft_count * 1100,
    ac.phase,
    NOW()
FROM 
    affiliate_cycle ac,
    generate_series(
        CURRENT_DATE - INTERVAL '7 days',
        CURRENT_DATE - INTERVAL '1 day',
        '1 day'::INTERVAL
    ) AS generate_series
WHERE ac.total_nft_count > 0
ON CONFLICT (user_id, date) DO NOTHING;
*/

-- 5. 生成されたデータの確認
SELECT 
    'Generated data verification' as info,
    user_id,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount
FROM user_daily_profit
WHERE date >= CURRENT_DATE - INTERVAL '7 days'
AND user_id IN ('7A9637', 'b5e6e7', 'Y2R456')
ORDER BY user_id, date DESC;