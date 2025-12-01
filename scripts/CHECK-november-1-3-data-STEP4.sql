-- ========================================
-- STEP 4: 11月全体の日数確認
-- ========================================

SELECT
    COUNT(*) as total_count,
    MIN(date) as min_date,
    MAX(date) as max_date,
    COUNT(DISTINCT date) as unique_dates
FROM daily_yield_log
WHERE date >= '2025-11-01' AND date <= '2025-11-30';
