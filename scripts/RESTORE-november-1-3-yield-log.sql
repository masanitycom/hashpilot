-- ========================================
-- 11月1日～3日の日利設定データを復元
-- ========================================
--
-- user_daily_profitから逆算してdaily_yield_logを復元
--
-- 作成日: 2025-12-01
-- ========================================

-- STEP 1: 11/1～11/3の実際の配布データを確認
WITH actual_distribution AS (
    SELECT
        date,
        SUM(daily_profit) as total_profit,
        COUNT(DISTINCT user_id) as user_count
    FROM user_daily_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-03'
    GROUP BY date
),
-- STEP 2: 運用中のNFT総数を取得（各日付時点）
nft_count_by_date AS (
    SELECT
        '2025-11-01'::date as date,
        (SELECT COUNT(*) FROM nft_master nm
         INNER JOIN users u ON nm.user_id = u.user_id
         WHERE nm.buyback_date IS NULL
           AND u.has_approved_nft = true
           AND u.operation_start_date IS NOT NULL
           AND u.operation_start_date <= '2025-11-01'
           AND u.is_pegasus_exchange = false) as nft_count
    UNION ALL
    SELECT
        '2025-11-02'::date,
        (SELECT COUNT(*) FROM nft_master nm
         INNER JOIN users u ON nm.user_id = u.user_id
         WHERE nm.buyback_date IS NULL
           AND u.has_approved_nft = true
           AND u.operation_start_date IS NOT NULL
           AND u.operation_start_date <= '2025-11-02'
           AND u.is_pegasus_exchange = false)
    UNION ALL
    SELECT
        '2025-11-03'::date,
        (SELECT COUNT(*) FROM nft_master nm
         INNER JOIN users u ON nm.user_id = u.user_id
         WHERE nm.buyback_date IS NULL
           AND u.has_approved_nft = true
           AND u.operation_start_date IS NOT NULL
           AND u.operation_start_date <= '2025-11-03'
           AND u.is_pegasus_exchange = false)
),
-- STEP 3: 日利率を逆算
calculated_rates AS (
    SELECT
        ad.date,
        ad.total_profit,
        ad.user_count,
        nc.nft_count,
        nc.nft_count * 1000 as total_investment,
        -- ユーザー利率 = 配布額 / 総投資額
        ROUND((ad.total_profit / NULLIF(nc.nft_count * 1000, 0)) * 100, 6) as user_rate,
        -- 日利率を逆算: user_rate = yield_rate × 0.7 × 0.6
        -- → yield_rate = user_rate / 0.42
        ROUND((ad.total_profit / NULLIF(nc.nft_count * 1000, 0) / 0.42) * 100, 6) as yield_rate,
        -- マージン率（11/1～11/3はマージン30%のはず）
        0.30 as margin_rate
    FROM actual_distribution ad
    INNER JOIN nft_count_by_date nc ON ad.date = nc.date
)
SELECT
    date,
    total_profit,
    user_count,
    nft_count,
    total_investment,
    user_rate as calculated_user_rate,
    yield_rate as calculated_yield_rate,
    margin_rate
FROM calculated_rates
ORDER BY date;
