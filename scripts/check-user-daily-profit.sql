-- user_daily_profitテーブルの詳細確認

-- 1. user_daily_profitテーブルの全データ確認
SELECT 
    'user_daily_profit data' as info,
    date,
    user_id,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    created_at
FROM user_daily_profit 
ORDER BY date DESC, daily_profit DESC
LIMIT 20;

-- 2. 日付別の統計
SELECT 
    'daily summary' as info,
    date,
    COUNT(*) as user_count,
    SUM(daily_profit) as total_profit,
    AVG(daily_profit) as avg_profit,
    MIN(daily_profit) as min_profit,
    MAX(daily_profit) as max_profit
FROM user_daily_profit 
GROUP BY date
ORDER BY date DESC;

-- 3. 特定ユーザー（サンプル）の利益履歴
SELECT 
    'sample user profits' as info,
    user_id,
    date,
    daily_profit,
    base_amount
FROM user_daily_profit 
WHERE user_id IN (
    SELECT user_id FROM affiliate_cycle 
    WHERE total_nft_count > 0 
    LIMIT 5
)
ORDER BY user_id, date DESC;

-- 4. 昨日（2025-07-09）のデータ確認
SELECT 
    'yesterday data (2025-07-09)' as info,
    COUNT(*) as user_count,
    SUM(daily_profit) as total_profit
FROM user_daily_profit 
WHERE date = '2025-07-09';

-- 5. daily_yield_logとuser_daily_profitの関連確認
SELECT 
    'yield log vs profit data' as info,
    dyl.date as yield_date,
    dyl.yield_rate,
    dyl.user_rate,
    dyl.total_users as yield_log_users,
    COUNT(udp.user_id) as profit_data_users,
    SUM(udp.daily_profit) as profit_total
FROM daily_yield_log dyl
LEFT JOIN user_daily_profit udp ON dyl.date = udp.date
GROUP BY dyl.date, dyl.yield_rate, dyl.user_rate, dyl.total_users
ORDER BY dyl.date DESC;