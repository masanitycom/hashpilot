-- ユーザー表示のテスト

-- 1. 7A9637ユーザーの全データ確認
SELECT 
    'All profit data for 7A9637' as info,
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
ORDER BY date DESC;

-- 2. 2025-07-09のデータを明示的に確認
SELECT 
    'Specific date check' as info,
    COUNT(*) as records,
    SUM(daily_profit::NUMERIC) as total_profit
FROM user_daily_profit
WHERE user_id = '7A9637'
AND date = '2025-07-09'::DATE;

-- 3. データ型の確認
SELECT 
    'Data type check' as info,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'user_daily_profit'
AND column_name IN ('daily_profit', 'yield_rate', 'user_rate', 'base_amount');

-- 4. 本日のテストデータを作成（必要に応じて）
-- 注意: これは本日の日付でテストデータを作成します
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
VALUES (
    '7A9637',
    CURRENT_DATE,
    7.39,
    0.016,
    0.00672,
    1100,
    'USDT',
    NOW()
)
ON CONFLICT (user_id, date) DO UPDATE SET
    daily_profit = EXCLUDED.daily_profit,
    updated_at = NOW();
*/