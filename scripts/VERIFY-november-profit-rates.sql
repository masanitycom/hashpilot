-- ========================================
-- 11月の日利率検証スクリプト
-- ========================================
--
-- 検証内容:
-- 1. 11月全体（1日～30日）の日利率: 3.2%期待
-- 2. 11月後半（15日～30日）の日利率: 3.69%期待
--
-- 作成日: 2025-12-01
-- ========================================

-- ========================================
-- 運用中のNFT総数と総投資額
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

-- ========================================
-- 11月全体（1日～30日）の利益集計
-- ========================================
november_full AS (
    SELECT
        SUM(daily_profit) as total_profit,
        COUNT(DISTINCT date) as days_count
    FROM user_daily_profit
    WHERE date >= '2025-11-01'
        AND date <= '2025-11-30'
),

-- ========================================
-- 11月後半（15日～30日）の利益集計
-- ========================================
november_second_half AS (
    SELECT
        SUM(daily_profit) as total_profit,
        COUNT(DISTINCT date) as days_count
    FROM user_daily_profit
    WHERE date >= '2025-11-15'
        AND date <= '2025-11-30'
)

-- ========================================
-- 結果を表示
-- ========================================
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

-- ========================================
-- 日別の詳細（11月全体）
-- ========================================
SELECT
    '日別詳細' as info;

SELECT
    date,
    SUM(daily_profit) as daily_total,
    COUNT(DISTINCT user_id) as user_count
FROM user_daily_profit
WHERE date >= '2025-11-01'
    AND date <= '2025-11-30'
GROUP BY date
ORDER BY date;

-- ========================================
-- 累積計算（月末時点での累積率）
-- ========================================
SELECT
    '累積計算' as info;

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
