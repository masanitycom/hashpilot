-- ========================================
-- STEP 2: 11月の日別詳細
-- ========================================

SELECT
    date,
    SUM(daily_profit) as daily_total,
    COUNT(DISTINCT user_id) as user_count
FROM user_daily_profit
WHERE date >= '2025-11-01'
    AND date <= '2025-11-30'
GROUP BY date
ORDER BY date;
