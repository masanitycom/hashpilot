-- ========================================
-- 11/30の日利処理でv_daily_pnlがどう計算されたか確認
-- ========================================

-- 1. daily_yield_log_v2の11/30データ
SELECT '=== 1. daily_yield_log_v2の11/30データ ===' as section;

SELECT
    date,
    total_profit_amount,
    total_nft_count,
    profit_per_nft,
    cumulative_gross_profit,
    cumulative_fee,
    cumulative_net_profit,
    daily_pnl,
    distribution_dividend,
    distribution_affiliate,
    distribution_stock,
    is_month_end,
    created_at AT TIME ZONE 'Asia/Tokyo' as created_at_jst
FROM daily_yield_log_v2
WHERE date = '2025-11-30';

-- 2. 11/29のデータ（前日）
SELECT '=== 2. daily_yield_log_v2の11/29データ（前日） ===' as section;

SELECT
    date,
    total_profit_amount,
    total_nft_count,
    profit_per_nft,
    cumulative_gross_profit,
    cumulative_fee,
    cumulative_net_profit,
    daily_pnl,
    distribution_dividend,
    distribution_affiliate,
    distribution_stock
FROM daily_yield_log_v2
WHERE date = '2025-11-29';

-- 3. v_daily_pnlの計算ロジックを再現
SELECT '=== 3. v_daily_pnlの計算を検証 ===' as section;

WITH prev_day AS (
    SELECT
        cumulative_net_profit as prev_cumulative_net
    FROM daily_yield_log_v2
    WHERE date < '2025-11-30'
    ORDER BY date DESC
    LIMIT 1
),
current_day AS (
    SELECT
        cumulative_net_profit as current_cumulative_net
    FROM daily_yield_log_v2
    WHERE date = '2025-11-30'
)
SELECT
    pd.prev_cumulative_net,
    cd.current_cumulative_net,
    (cd.current_cumulative_net - pd.prev_cumulative_net) as calculated_daily_pnl,
    (SELECT daily_pnl FROM daily_yield_log_v2 WHERE date = '2025-11-30') as recorded_daily_pnl,
    (cd.current_cumulative_net - pd.prev_cumulative_net) -
    (SELECT daily_pnl FROM daily_yield_log_v2 WHERE date = '2025-11-30') as difference
FROM prev_day pd, current_day cd;

-- 4. distribution_dividendの検証
SELECT '=== 4. distribution_dividendの検証 ===' as section;

SELECT
    daily_pnl,
    distribution_dividend,
    (daily_pnl * 0.60) as expected_distribution_dividend,
    distribution_dividend - (daily_pnl * 0.60) as difference,
    CASE
        WHEN distribution_dividend = 0 THEN 'ゼロ（affiliate_cycle更新されない！）'
        ELSE 'ゼロ以外（affiliate_cycle更新される）'
    END as will_update_affiliate_cycle
FROM daily_yield_log_v2
WHERE date = '2025-11-30';

-- 5. 11月全体のdaily_pnl推移
SELECT '=== 5. 11月のdaily_pnl推移 ===' as section;

SELECT
    date,
    total_profit_amount,
    daily_pnl,
    distribution_dividend,
    distribution_affiliate,
    distribution_stock,
    CASE
        WHEN distribution_dividend = 0 THEN '❌'
        ELSE '✅'
    END as affiliate_cycle_updated
FROM daily_yield_log_v2
WHERE date >= '2025-11-01'
  AND date <= '2025-11-30'
ORDER BY date;

-- 6. 累積計算の検証
SELECT '=== 6. 累積計算の検証 ===' as section;

SELECT
    date,
    total_profit_amount,
    cumulative_gross_profit,
    cumulative_fee,
    cumulative_net_profit,
    daily_pnl,
    (cumulative_gross_profit * 0.30) as expected_fee,
    cumulative_fee - (cumulative_gross_profit * 0.30) as fee_difference
FROM daily_yield_log_v2
WHERE date >= '2025-11-01'
  AND date <= '2025-11-30'
ORDER BY date DESC
LIMIT 10;

-- サマリー
DO $$
DECLARE
    v_1130_pnl NUMERIC;
    v_1130_dividend NUMERIC;
    v_1130_total_profit NUMERIC;
BEGIN
    SELECT
        daily_pnl,
        distribution_dividend,
        total_profit_amount
    INTO
        v_1130_pnl,
        v_1130_dividend,
        v_1130_total_profit
    FROM daily_yield_log_v2
    WHERE date = '2025-11-30';

    RAISE NOTICE '===========================================';
    RAISE NOTICE '📊 11/30のv_daily_pnl計算検証';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '入力値:';
    RAISE NOTICE '  total_profit_amount: $%', v_1130_total_profit;
    RAISE NOTICE '';
    RAISE NOTICE '計算結果:';
    RAISE NOTICE '  daily_pnl: $%', v_1130_pnl;
    RAISE NOTICE '  distribution_dividend (60%%): $%', v_1130_dividend;
    RAISE NOTICE '';
    IF v_1130_dividend = 0 THEN
        RAISE NOTICE '🚨 重大な問題:';
        RAISE NOTICE '  distribution_dividend = 0 のため、';
        RAISE NOTICE '  STEP 4の "IF v_distribution_dividend != 0" が FALSE';
        RAISE NOTICE '  → affiliate_cycleが更新されない！';
    ELSE
        RAISE NOTICE '✅ distribution_dividend != 0';
        RAISE NOTICE '  → affiliate_cycleは更新されるはず';
    END IF;
    RAISE NOTICE '===========================================';
END $$;
