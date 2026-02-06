-- ========================================
-- 1月度個人利益を約$12/NFTに調整
-- ========================================
-- 調整内容:
-- 1/29: -$15,522 → -$7,500
-- 1/30: -$2,582 → -$5,500
-- 1/31: -$14,916 → -$8,600
-- ========================================

-- ========================================
-- STEP 1: 修正前の状態確認
-- ========================================
SELECT '=== STEP 1: 修正前の状態 ===' as section;
SELECT
  date,
  total_profit_amount as 運用利益,
  ROUND(distribution_dividend::numeric, 2) as 配当60pct
FROM daily_yield_log_v2
WHERE date >= '2026-01-29' AND date <= '2026-01-31'
ORDER BY date;

SELECT
  '0D4493の修正前1月利益' as info,
  ROUND(SUM(daily_profit)::numeric, 3) as 個人利益
FROM nft_daily_profit
WHERE user_id = '0D4493'
  AND date >= '2026-01-01' AND date <= '2026-01-31';

-- ========================================
-- STEP 2: daily_yield_log_v2を修正
-- ========================================
SELECT '=== STEP 2: 運用利益を修正 ===' as section;

UPDATE daily_yield_log_v2 SET total_profit_amount = -7500 WHERE date = '2026-01-29';
UPDATE daily_yield_log_v2 SET total_profit_amount = -5500 WHERE date = '2026-01-30';
UPDATE daily_yield_log_v2 SET total_profit_amount = -8600 WHERE date = '2026-01-31';

-- ========================================
-- STEP 3: 1/29以降の累積計算を再計算
-- ========================================
SELECT '=== STEP 3: 累積計算を再計算 ===' as section;

DO $$
DECLARE
  v_record RECORD;
  v_prev_cumulative_gross NUMERIC := 0;
  v_prev_cumulative_net NUMERIC := 0;
  v_cumulative_gross NUMERIC;
  v_cumulative_fee NUMERIC;
  v_cumulative_net NUMERIC;
  v_daily_pnl NUMERIC;
  v_fee_rate NUMERIC := 0.30;
BEGIN
  -- 1/28の累積値を取得
  SELECT cumulative_gross_profit, cumulative_net_profit
  INTO v_prev_cumulative_gross, v_prev_cumulative_net
  FROM daily_yield_log_v2
  WHERE date = '2026-01-28';

  -- 1/29以降を順番に再計算
  FOR v_record IN
    SELECT id, date, total_profit_amount, total_nft_count
    FROM daily_yield_log_v2
    WHERE date >= '2026-01-29'
    ORDER BY date
  LOOP
    v_cumulative_gross := v_prev_cumulative_gross + v_record.total_profit_amount;
    v_cumulative_fee := v_fee_rate * GREATEST(v_cumulative_gross, 0);
    v_cumulative_net := v_cumulative_gross - v_cumulative_fee;
    v_daily_pnl := v_cumulative_net - v_prev_cumulative_net;

    UPDATE daily_yield_log_v2
    SET
      profit_per_nft = v_record.total_profit_amount::numeric / v_record.total_nft_count,
      cumulative_gross_profit = v_cumulative_gross,
      cumulative_fee = v_cumulative_fee,
      cumulative_net_profit = v_cumulative_net,
      daily_pnl = v_daily_pnl,
      distribution_dividend = v_daily_pnl * 0.60,
      distribution_affiliate = v_daily_pnl * 0.30,
      distribution_stock = v_daily_pnl * 0.10
    WHERE id = v_record.id;

    v_prev_cumulative_gross := v_cumulative_gross;
    v_prev_cumulative_net := v_cumulative_net;

    RAISE NOTICE '% を再計算: daily_pnl=%, distribution=%',
      v_record.date, ROUND(v_daily_pnl::numeric, 2), ROUND((v_daily_pnl * 0.60)::numeric, 2);
  END LOOP;
END $$;

-- ========================================
-- STEP 4: nft_daily_profitを再計算（1/29, 1/30, 1/31）
-- ========================================
SELECT '=== STEP 4: nft_daily_profit再計算 ===' as section;

DO $$
DECLARE
  v_date DATE;
  v_yield_record RECORD;
  v_user_record RECORD;
  v_old_profit NUMERIC;
  v_new_profit NUMERIC;
  v_diff NUMERIC;
  v_total_diff NUMERIC := 0;
BEGIN
  FOR v_date IN SELECT unnest(ARRAY['2026-01-29'::date, '2026-01-30'::date, '2026-01-31'::date])
  LOOP
    SELECT distribution_dividend, total_nft_count
    INTO v_yield_record
    FROM daily_yield_log_v2
    WHERE date = v_date;

    FOR v_user_record IN
      SELECT user_id, COUNT(*) as nft_count
      FROM nft_daily_profit
      WHERE date = v_date
      GROUP BY user_id
    LOOP
      SELECT SUM(daily_profit)
      INTO v_old_profit
      FROM nft_daily_profit
      WHERE user_id = v_user_record.user_id AND date = v_date;

      v_new_profit := (v_yield_record.distribution_dividend / v_yield_record.total_nft_count) * v_user_record.nft_count;
      v_diff := v_new_profit - v_old_profit;

      UPDATE nft_daily_profit
      SET daily_profit = (v_yield_record.distribution_dividend / v_yield_record.total_nft_count)
      WHERE user_id = v_user_record.user_id AND date = v_date;

      UPDATE affiliate_cycle
      SET available_usdt = available_usdt + v_diff,
          updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_diff := v_total_diff + v_diff;
    END LOOP;

    RAISE NOTICE '% の日利を再計算しました', v_date;
  END LOOP;

  RAISE NOTICE 'available_usdt総調整額: $%', ROUND(v_total_diff::numeric, 2);
END $$;

-- ========================================
-- STEP 5: 修正後の確認
-- ========================================
SELECT '=== STEP 5: 修正後の状態 ===' as section;

SELECT
  date,
  total_profit_amount as 運用利益,
  ROUND(distribution_dividend::numeric, 2) as 配当60pct
FROM daily_yield_log_v2
WHERE date >= '2026-01-29' AND date <= '2026-01-31'
ORDER BY date;

-- 1月配当合計
SELECT
  '1月配当合計' as info,
  ROUND(SUM(distribution_dividend)::numeric, 2) as 配当合計
FROM daily_yield_log_v2
WHERE date >= '2026-01-01' AND date <= '2026-01-31';

-- 0D4493の1月個人利益
SELECT
  '0D4493の1月個人利益' as info,
  ROUND(SUM(daily_profit)::numeric, 3) as 個人利益
FROM nft_daily_profit
WHERE user_id = '0D4493'
  AND date >= '2026-01-01' AND date <= '2026-01-31';
