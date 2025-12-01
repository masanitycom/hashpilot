-- ========================================
-- STEP 1: 11月の日利率検証（基本集計）
-- ========================================

WITH active_nfts AS (
    SELECT COUNT(*) as total_nft_count
    FROM nft_master nm
    INNER JOIN users u ON nm.user_id = u.user_id
    WHERE nm.buyback_date IS NULL
        AND u.has_approved_nft = true
        AND u.operation_start_date IS NOT NULL
        AND u.is_pegasus_exchange = false
),
total_investment AS (
    SELECT total_nft_count * 1000 as total_investment
    FROM active_nfts
),
november_full AS (
    SELECT
        SUM(daily_profit) as total_profit,
        COUNT(DISTINCT date) as days_count
    FROM user_daily_profit
    WHERE date >= '2025-11-01'
        AND date <= '2025-11-30'
),
november_second_half AS (
    SELECT
        SUM(daily_profit) as total_profit,
        COUNT(DISTINCT date) as days_count
    FROM user_daily_profit
    WHERE date >= '2025-11-15'
        AND date <= '2025-11-30'
)
SELECT
    '11月全体（1～30日）' as period,
    ti.total_investment as total_investment,
    nf.total_profit as total_profit,
    nf.days_count as days_count,
    ROUND((nf.total_profit / NULLIF(ti.total_investment, 0)) * 100, 4) as profit_rate_percent,
    '3.2%' as expected_rate
FROM total_investment ti, november_full nf

UNION ALL

SELECT
    '11月後半（15～30日）' as period,
    ti.total_investment as total_investment,
    nsh.total_profit as total_profit,
    nsh.days_count as days_count,
    ROUND((nsh.total_profit / NULLIF(ti.total_investment, 0)) * 100, 4) as profit_rate_percent,
    '3.69%' as expected_rate
FROM total_investment ti, november_second_half nsh;
