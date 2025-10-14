-- ========================================
-- 昨日と今日のデータ確認
-- ========================================

-- 1. 今日の日付（日本時間）
SELECT
    'システム日付' as info,
    CURRENT_DATE as today,
    (CURRENT_DATE - INTERVAL '1 day')::DATE as yesterday;

-- 2. 昨日（10/11）のuser_daily_profitデータ
SELECT
    '昨日（10/11）のデータ' as section,
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as user_count,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date = '2025-10-11';

-- 3. 昨日（10/11）のサンプルデータ
SELECT
    'サンプルデータ' as section,
    user_id,
    daily_profit,
    yield_rate,
    created_at
FROM user_daily_profit
WHERE date = '2025-10-11'
ORDER BY user_id
LIMIT 10;

-- 4. 今日（10/12）のuser_daily_profitデータ
SELECT
    '今日（10/12）のデータ' as section,
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as user_count,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date = '2025-10-12';

-- 5. 最新の日利設定日を確認
SELECT
    '最新の日利設定' as section,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log
ORDER BY date DESC
LIMIT 5;

-- 6. 特定ユーザーの全期間データを確認（運用開始済みユーザー1名）
WITH sample_user AS (
    SELECT user_id
    FROM users
    WHERE operation_start_date IS NOT NULL
      AND operation_start_date <= CURRENT_DATE
      AND has_approved_nft = true
    LIMIT 1
)
SELECT
    u.user_id,
    u.email,
    u.operation_start_date,
    udp.date,
    udp.daily_profit,
    udp.yield_rate
FROM users u
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.user_id = (SELECT user_id FROM sample_user)
ORDER BY udp.date DESC
LIMIT 10;
