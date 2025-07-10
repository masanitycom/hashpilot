-- 日付問題の修正

-- 1. 現在の時刻設定を確認
SHOW timezone;

-- 2. 日付関連の確認
SELECT 
    'Date comparison' as info,
    CURRENT_DATE as server_today,
    CURRENT_DATE - INTERVAL '1 day' as server_yesterday,
    '2025-07-09'::DATE as target_date,
    (CURRENT_DATE - INTERVAL '1 day') = '2025-07-09'::DATE as dates_match;

-- 3. user_daily_profitの日付分布を確認
SELECT 
    date,
    COUNT(*) as user_count,
    SUM(daily_profit::NUMERIC) as total_profit,
    MIN(created_at) as first_created,
    MAX(created_at) as last_created
FROM user_daily_profit
GROUP BY date
ORDER BY date DESC;

-- 4. 特定ユーザーの最新データを確認
SELECT 
    user_id,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    created_at
FROM user_daily_profit
WHERE user_id = '7A9637'
ORDER BY date DESC
LIMIT 5;

-- 5. 今日の日付でテストデータを作成（デバッグ用）
-- 注意: これは今日の日付でデータを作成します
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
    CURRENT_DATE - INTERVAL '1 day',  -- 昨日の日付
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    NOW()
FROM user_daily_profit
WHERE date = '2025-07-09'::DATE
AND user_id = '7A9637'
ON CONFLICT (user_id, date) DO UPDATE SET
    daily_profit = EXCLUDED.daily_profit,
    yield_rate = EXCLUDED.yield_rate,
    user_rate = EXCLUDED.user_rate,
    updated_at = NOW();
*/