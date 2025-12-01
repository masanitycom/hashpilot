-- ========================================
-- STEP 2: 日別詳細と累積計算
-- ========================================

SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    SUM(user_rate) OVER (ORDER BY date) as cumulative_user_rate
FROM daily_yield_log
WHERE date >= '2025-11-01' AND date <= '2025-11-30'
ORDER BY date;
