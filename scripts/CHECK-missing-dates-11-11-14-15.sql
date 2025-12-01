-- ========================================
-- 11/11、11/14、11/15の欠落データを確認
-- ========================================

-- user_daily_profitテーブルで実際の配布データを確認
SELECT
    date,
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as user_count,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date IN ('2025-11-11', '2025-11-14', '2025-11-15')
GROUP BY date
ORDER BY date;

-- 11/10から11/16までの連続性を確認
SELECT
    date,
    COUNT(DISTINCT user_id) as user_count,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date >= '2025-11-10' AND date <= '2025-11-16'
GROUP BY date
ORDER BY date;
