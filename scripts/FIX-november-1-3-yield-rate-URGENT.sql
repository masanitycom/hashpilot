-- ========================================
-- 11月1日～3日のyield_rateを緊急修正
-- ========================================

-- 2025-11-01: user_rate -0.017% → yield_rate -0.028%
UPDATE daily_yield_log
SET yield_rate = -0.028333
WHERE date = '2025-11-01';

-- 2025-11-02: user_rate -0.004% → yield_rate -0.007%
UPDATE daily_yield_log
SET yield_rate = -0.006667
WHERE date = '2025-11-02';

-- 2025-11-03: user_rate -0.168% → yield_rate -0.280%
UPDATE daily_yield_log
SET yield_rate = -0.280000
WHERE date = '2025-11-03';

-- 修正結果を確認
SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    ROUND((yield_rate * (1 - margin_rate) * 0.6)::numeric, 6) as calculated_user_rate,
    CASE
        WHEN ABS(user_rate - (yield_rate * (1 - margin_rate) * 0.6)) < 0.001 THEN '✅'
        ELSE '❌'
    END as check
FROM daily_yield_log
WHERE date >= '2025-11-01' AND date <= '2025-11-04'
ORDER BY date;
