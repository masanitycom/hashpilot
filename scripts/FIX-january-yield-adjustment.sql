-- ========================================
-- 1月日利調整スクリプト
-- ========================================
-- 目的: 1月の配当合計を+$1.26にする
-- 修正対象: 1/29, 1/30, 1/31
--
-- 修正内容:
-- 1/29: -$17,300 → -$15,942 (+$1,358)
-- 1/30: -$4,500 → -$3,007 (+$1,493)
-- 1/31: -$16,700 → -$15,335 (+$1,365)
-- 合計: +$4,216

-- ========================================
-- STEP 1: 現状確認
-- ========================================
SELECT '=== STEP 1: 修正前の状態 ===' as section;
SELECT date, total_profit_amount, total_nft_count,
       ROUND(daily_pnl::numeric, 2) as daily_pnl,
       ROUND(distribution_dividend::numeric, 2) as distribution_dividend
FROM daily_yield_log_v2
WHERE date >= '2026-01-29'
ORDER BY date;

-- ========================================
-- STEP 2: daily_yield_log_v2を修正
-- ========================================
SELECT '=== STEP 2: daily_yield_log_v2を修正 ===' as section;

-- 1/29を修正
UPDATE daily_yield_log_v2
SET total_profit_amount = -15942
WHERE date = '2026-01-29';

-- 1/30を修正
UPDATE daily_yield_log_v2
SET total_profit_amount = -3007
WHERE date = '2026-01-30';

-- 1/31を修正
UPDATE daily_yield_log_v2
SET total_profit_amount = -15335
WHERE date = '2026-01-31';

SELECT '運用利益を修正しました' as result;

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
  END LOOP;
END $$;

SELECT '累積計算を再計算しました' as result;

-- ========================================
-- STEP 4: nft_daily_profitを再計算（1/29, 1/30, 1/31）
-- ========================================
SELECT '=== STEP 4: nft_daily_profitを再計算 ===' as section;

DO $$
DECLARE
  v_date DATE;
  v_yield_record RECORD;
  v_user_record RECORD;
  v_nft_record RECORD;
  v_old_profit NUMERIC;
  v_new_profit NUMERIC;
  v_diff NUMERIC;
  v_total_nft_count INTEGER;
BEGIN
  -- 1/29, 1/30, 1/31をループ
  FOR v_date IN SELECT unnest(ARRAY['2026-01-29'::date, '2026-01-30'::date, '2026-01-31'::date])
  LOOP
    -- その日の日利ログを取得
    SELECT distribution_dividend, total_nft_count
    INTO v_yield_record
    FROM daily_yield_log_v2
    WHERE date = v_date;

    -- 各ユーザーのNFT数を取得して更新
    FOR v_user_record IN
      SELECT user_id, COUNT(*) as nft_count
      FROM nft_daily_profit
      WHERE date = v_date
      GROUP BY user_id
    LOOP
      -- 古い利益合計を取得
      SELECT SUM(daily_profit)
      INTO v_old_profit
      FROM nft_daily_profit
      WHERE user_id = v_user_record.user_id AND date = v_date;

      -- 新しい利益を計算
      v_new_profit := (v_yield_record.distribution_dividend / v_yield_record.total_nft_count) * v_user_record.nft_count;
      v_diff := v_new_profit - v_old_profit;

      -- nft_daily_profitを更新
      UPDATE nft_daily_profit
      SET daily_profit = (v_yield_record.distribution_dividend / v_yield_record.total_nft_count)
      WHERE user_id = v_user_record.user_id AND date = v_date;

      -- affiliate_cycleを更新
      UPDATE affiliate_cycle
      SET available_usdt = available_usdt + v_diff,
          updated_at = NOW()
      WHERE user_id = v_user_record.user_id;
    END LOOP;

    RAISE NOTICE '% の日利を再計算しました', v_date;
  END LOOP;
END $$;

SELECT 'nft_daily_profitとaffiliate_cycleを更新しました' as result;

-- ========================================
-- STEP 5: 修正後の確認
-- ========================================
SELECT '=== STEP 5: 修正後の状態 ===' as section;
SELECT date, total_profit_amount, total_nft_count,
       ROUND(daily_pnl::numeric, 2) as daily_pnl,
       ROUND(distribution_dividend::numeric, 2) as distribution_dividend
FROM daily_yield_log_v2
WHERE date >= '2026-01-29'
ORDER BY date;

-- 1月配当合計を確認
SELECT '=== 1月配当合計 ===' as section;
SELECT ROUND(SUM(distribution_dividend)::numeric, 2) as 一月配当合計
FROM daily_yield_log_v2
WHERE date >= '2026-01-01' AND date <= '2026-01-31';

-- ========================================
-- STEP 6: 1月紹介報酬計算
-- ========================================
SELECT '=== STEP 6: 紹介報酬計算を実行 ===' as section;
SELECT * FROM process_monthly_referral_reward(2026, 1, true);

-- ========================================
-- STEP 7: 月末出金処理
-- ========================================
SELECT '=== STEP 7: 月末出金処理を実行 ===' as section;
SELECT * FROM process_monthly_withdrawals('2026-01-31'::date);
