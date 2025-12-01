-- ========================================
-- STEP 3: 累積計算（月末時点での累積率）
-- ========================================

WITH daily_cumulative AS (
    SELECT
        date,
        SUM(daily_profit) as daily_total,
        SUM(SUM(daily_profit)) OVER (ORDER BY date) as cumulative_total
    FROM user_daily_profit
    WHERE date >= '2025-11-01'
        AND date <= '2025-11-30'
    GROUP BY date
),
total_investment AS (
    SELECT COUNT(*) * 1000 as total_investment
    FROM nft_master nm
    INNER JOIN users u ON nm.user_id = u.user_id
    WHERE nm.buyback_date IS NULL
        AND u.has_approved_nft = true
        AND u.operation_start_date IS NOT NULL
        AND u.is_pegasus_exchange = false
)
SELECT
    dc.date,
    dc.daily_total,
    dc.cumulative_total,
    ti.total_investment,
    ROUND((dc.cumulative_total / NULLIF(ti.total_investment, 0)) * 100, 4) as cumulative_rate_percent
FROM daily_cumulative dc, total_investment ti
ORDER BY dc.date;
