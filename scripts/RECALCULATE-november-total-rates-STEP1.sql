-- ========================================
-- STEP 1: 11月全体の合計ユーザー受取率
-- ========================================

WITH november_settings AS (
    SELECT
        date,
        yield_rate,
        margin_rate,
        user_rate
    FROM daily_yield_log
    WHERE date >= '2025-11-01' AND date <= '2025-11-30'
)
SELECT
    '11月全体（1～30日）' as period,
    COUNT(*) as days_count,
    ROUND(SUM(user_rate), 4) as total_user_rate,
    '3.2%期待' as note
FROM november_settings

UNION ALL

SELECT
    '11月後半（15～30日）' as period,
    COUNT(*) as days_count,
    ROUND(SUM(user_rate), 4) as total_user_rate,
    '3.69%期待' as note
FROM november_settings
WHERE date >= '2025-11-15';
