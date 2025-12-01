-- ========================================
-- 管理画面で設定した日利率から11月の合計を計算
-- ========================================

WITH november_settings AS (
    -- 11月の日利設定データ（管理画面からの値）
    SELECT '2025-11-04' as date, -1.159 as yield_rate, 0 as margin_rate UNION ALL
    SELECT '2025-11-05', -0.165, 0 UNION ALL
    SELECT '2025-11-06', 0.138, 0 UNION ALL
    SELECT '2025-11-07', -0.757, 0 UNION ALL
    SELECT '2025-11-08', -0.001, 0 UNION ALL
    SELECT '2025-11-09', 0.381, 0 UNION ALL
    SELECT '2025-11-10', 0.880, 0 UNION ALL
    SELECT '2025-11-12', -0.433, 0 UNION ALL
    SELECT '2025-11-13', -0.652, 0 UNION ALL
    SELECT '2025-11-16', 0.520, 30 UNION ALL
    SELECT '2025-11-17', 1.180, 30 UNION ALL
    SELECT '2025-11-18', 0.717, 30 UNION ALL
    SELECT '2025-11-19', 0.240, 30 UNION ALL
    SELECT '2025-11-20', -0.340, 0 UNION ALL
    SELECT '2025-11-21', -0.355, 30 UNION ALL
    SELECT '2025-11-22', 0.720, 30 UNION ALL
    SELECT '2025-11-23', 0.955, 30 UNION ALL
    SELECT '2025-11-24', 0.710, 30 UNION ALL
    SELECT '2025-11-25', 0.952, 30 UNION ALL
    SELECT '2025-11-26', 1.900, 30 UNION ALL
    SELECT '2025-11-27', 0.240, 30 UNION ALL
    SELECT '2025-11-28', 0.244, 30 UNION ALL
    SELECT '2025-11-29', 0.479, 30 UNION ALL
    SELECT '2025-11-30', 0.236, 30
),
calculation AS (
    SELECT
        date,
        yield_rate,
        margin_rate,
        -- ユーザー利率の計算
        CASE
            WHEN margin_rate = 0 THEN yield_rate
            ELSE yield_rate * (1 - margin_rate/100.0) * 0.6
        END as user_rate,
        -- 累積計算
        SUM(CASE
            WHEN margin_rate = 0 THEN yield_rate
            ELSE yield_rate * (1 - margin_rate/100.0) * 0.6
        END) OVER (ORDER BY date) as cumulative_rate
    FROM november_settings
)
SELECT
    date,
    yield_rate,
    margin_rate,
    ROUND(user_rate::numeric, 4) as user_rate,
    ROUND(cumulative_rate::numeric, 4) as cumulative_rate
FROM calculation
ORDER BY date;

-- 11月全体の合計
WITH november_settings AS (
    SELECT '2025-11-04' as date, -1.159 as yield_rate, 0 as margin_rate UNION ALL
    SELECT '2025-11-05', -0.165, 0 UNION ALL
    SELECT '2025-11-06', 0.138, 0 UNION ALL
    SELECT '2025-11-07', -0.757, 0 UNION ALL
    SELECT '2025-11-08', -0.001, 0 UNION ALL
    SELECT '2025-11-09', 0.381, 0 UNION ALL
    SELECT '2025-11-10', 0.880, 0 UNION ALL
    SELECT '2025-11-12', -0.433, 0 UNION ALL
    SELECT '2025-11-13', -0.652, 0 UNION ALL
    SELECT '2025-11-16', 0.520, 30 UNION ALL
    SELECT '2025-11-17', 1.180, 30 UNION ALL
    SELECT '2025-11-18', 0.717, 30 UNION ALL
    SELECT '2025-11-19', 0.240, 30 UNION ALL
    SELECT '2025-11-20', -0.340, 0 UNION ALL
    SELECT '2025-11-21', -0.355, 30 UNION ALL
    SELECT '2025-11-22', 0.720, 30 UNION ALL
    SELECT '2025-11-23', 0.955, 30 UNION ALL
    SELECT '2025-11-24', 0.710, 30 UNION ALL
    SELECT '2025-11-25', 0.952, 30 UNION ALL
    SELECT '2025-11-26', 1.900, 30 UNION ALL
    SELECT '2025-11-27', 0.240, 30 UNION ALL
    SELECT '2025-11-28', 0.244, 30 UNION ALL
    SELECT '2025-11-29', 0.479, 30 UNION ALL
    SELECT '2025-11-30', 0.236, 30
)
SELECT
    '11月全体（4～30日）' as period,
    COUNT(*) as days_count,
    ROUND(SUM(CASE
        WHEN margin_rate = 0 THEN yield_rate
        ELSE yield_rate * (1 - margin_rate/100.0) * 0.6
    END)::numeric, 4) as total_user_rate,
    '3.2%期待' as note
FROM november_settings

UNION ALL

-- 11月後半の合計（15～30日）
SELECT
    '11月後半（15～30日）' as period,
    COUNT(*) as days_count,
    ROUND(SUM(CASE
        WHEN margin_rate = 0 THEN yield_rate
        ELSE yield_rate * (1 - margin_rate/100.0) * 0.6
    END)::numeric, 4) as total_user_rate,
    '3.69%期待' as note
FROM november_settings
WHERE date >= '2025-11-15';
