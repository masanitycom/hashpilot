-- ========================================
-- 11月全体の日利率を再計算
-- ========================================

-- daily_yield_logから11月全体の合計を計算
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

-- 11月後半（15～30日）
SELECT
    '11月後半（15～30日）' as period,
    COUNT(*) as days_count,
    ROUND(SUM(user_rate), 4) as total_user_rate,
    '3.69%期待' as note
FROM november_settings
WHERE date >= '2025-11-15';

-- 日別詳細
SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    -- 累積計算
    SUM(user_rate) OVER (ORDER BY date) as cumulative_user_rate
FROM daily_yield_log
WHERE date >= '2025-11-01' AND date <= '2025-11-30'
ORDER BY date;
