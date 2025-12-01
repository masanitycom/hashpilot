-- ========================================
-- STEP 3: user_daily_profitテーブルの確認
-- ========================================

SELECT
    date,
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as user_count,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-03'
GROUP BY date
ORDER BY date;
