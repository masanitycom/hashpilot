-- 日利データの確認と修正

-- 1. user_daily_profitテーブルの現在のデータを確認
SELECT 
    'Recent daily profit records' as info,
    user_id,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    created_at
FROM user_daily_profit
WHERE date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY date DESC, user_id
LIMIT 20;

-- 2. 昨日の日付でデータがあるか確認
SELECT 
    'Yesterday data check' as info,
    COUNT(*) as record_count,
    date
FROM user_daily_profit
WHERE date = CURRENT_DATE - INTERVAL '1 day'
GROUP BY date;

-- 3. daily_yield_logテーブルの確認
SELECT 
    'Daily yield log' as info,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
FROM daily_yield_log
WHERE date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY date DESC;

-- 4. affiliate_cycleテーブルでNFTを持っているユーザーを確認
SELECT 
    'Users with NFTs' as info,
    COUNT(*) as user_count,
    SUM(total_nft_count) as total_nfts
FROM affiliate_cycle
WHERE total_nft_count > 0;

-- 5. 特定のユーザー（例：7A9637）の日利データを確認
SELECT 
    'User 7A9637 profit history' as info,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase
FROM user_daily_profit
WHERE user_id = '7A9637'
ORDER BY date DESC
LIMIT 10;

-- 6. テスト用に昨日の日利データを手動で作成（必要に応じて）
-- 実際に実行する前に、適切な値に調整してください
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
    user_id,
    CURRENT_DATE - INTERVAL '1 day',
    total_nft_count * 1100 * 0.00672,  -- 1.6% * (1-30%) * 0.6 = 0.672%
    0.016,
    0.00672,
    total_nft_count * 1100,
    phase,
    NOW()
FROM affiliate_cycle
WHERE total_nft_count > 0
ON CONFLICT (user_id, date) DO NOTHING;
*/

-- 7. 今月の累積利益の確認
WITH monthly_profit AS (
    SELECT 
        user_id,
        SUM(daily_profit) as total_profit,
        COUNT(*) as days_count
    FROM user_daily_profit
    WHERE date >= DATE_TRUNC('month', CURRENT_DATE)
    AND date < CURRENT_DATE
    GROUP BY user_id
)
SELECT 
    'Monthly profit summary' as info,
    user_id,
    total_profit,
    days_count
FROM monthly_profit
WHERE user_id IN ('7A9637', 'b5e6e7', 'Y2R456')
ORDER BY total_profit DESC;