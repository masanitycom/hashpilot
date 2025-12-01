-- ========================================
-- 11月全日（1～30日）の配布状況を確認
-- ========================================

-- user_daily_profitで実際の配布があった日を確認
SELECT
    date,
    COUNT(DISTINCT user_id) as user_count,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-30'
GROUP BY date
ORDER BY date;

-- daily_yield_logに記録されている日を確認
SELECT
    date,
    yield_rate,
    user_rate
FROM daily_yield_log
WHERE date >= '2025-11-01' AND date <= '2025-11-30'
ORDER BY date;

-- 配布はあるのにdaily_yield_logに記録がない日を特定
SELECT
    udp.date,
    COUNT(DISTINCT udp.user_id) as user_count,
    SUM(udp.daily_profit) as total_profit,
    '❌ daily_yield_logに記録なし' as status
FROM user_daily_profit udp
WHERE udp.date >= '2025-11-01' AND udp.date <= '2025-11-30'
    AND NOT EXISTS (
        SELECT 1 FROM daily_yield_log dyl WHERE dyl.date = udp.date
    )
GROUP BY udp.date
ORDER BY udp.date;
