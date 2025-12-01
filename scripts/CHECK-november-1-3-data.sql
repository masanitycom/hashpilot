-- ========================================
-- 11月1日～3日のデータ確認
-- ========================================

-- daily_yield_logテーブルの確認
SELECT
    'daily_yield_log' as table_name,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    total_users,
    created_at
FROM daily_yield_log
WHERE date >= '2025-11-01' AND date <= '2025-11-03'
ORDER BY date;

-- user_daily_profitテーブルの確認
SELECT
    'user_daily_profit' as table_name,
    date,
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as user_count,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-03'
GROUP BY date
ORDER BY date;

-- 11月全体の日数確認
SELECT
    'daily_yield_log全件数' as info,
    COUNT(*) as total_count,
    MIN(date) as min_date,
    MAX(date) as max_date,
    COUNT(DISTINCT date) as unique_dates
FROM daily_yield_log
WHERE date >= '2025-11-01' AND date <= '2025-11-30';
