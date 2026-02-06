-- ========================================
-- 1月度個人利益を約$12/NFTに調整（完全版）
-- ========================================
-- 調整内容:
-- 1/29: -$15,522 → -$7,500
-- 1/30: -$2,582 → -$5,500
-- 1/31: -$14,916 → -$8,600
--
-- 処理内容:
-- 1. 関数バグ修正（上書き時のcum_usdt二重加算防止）
-- 2. 日利データ調整
-- 3. nft_daily_profit再計算
-- 4. 紹介報酬再計算
-- 5. フェーズ再計算
-- 6. 月末出金データ再作成
-- ========================================

-- ========================================
-- STEP 1: 修正前の状態確認
-- ========================================
SELECT '=== STEP 1: 修正前の状態 ===' as section;

SELECT
  '0D4493の修正前' as info,
  ROUND(SUM(daily_profit)::numeric, 3) as 個人利益
FROM nft_daily_profit
WHERE user_id = '0D4493'
  AND date >= '2026-01-01' AND date <= '2026-01-31';

SELECT
  '1月配当合計（修正前）' as info,
  ROUND(SUM(distribution_dividend)::numeric, 2) as 配当合計
FROM daily_yield_log_v2
WHERE date >= '2026-01-01' AND date <= '2026-01-31';

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
  SELECT cumulative_gross_profit, cumulative_net_profit
  INTO v_prev_cumulative_gross, v_prev_cumulative_net
  FROM daily_yield_log_v2
  WHERE date = '2026-01-28';

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
    END LOOP;
  END LOOP;
END $$;

-- ========================================
-- STEP 5: 個人利益の確認
-- ========================================
SELECT '=== STEP 5: 個人利益の確認 ===' as section;

SELECT
  '0D4493の1月個人利益' as info,
  ROUND(SUM(daily_profit)::numeric, 3) as 個人利益
FROM nft_daily_profit
WHERE user_id = '0D4493'
  AND date >= '2026-01-01' AND date <= '2026-01-31';

SELECT
  '1月配当合計' as info,
  ROUND(SUM(distribution_dividend)::numeric, 2) as 配当合計
FROM daily_yield_log_v2
WHERE date >= '2026-01-01' AND date <= '2026-01-31';

-- ========================================
-- STEP 6: 1月紹介報酬を再計算
-- まずcum_usdtから既存の1月紹介報酬を減算
-- ========================================
SELECT '=== STEP 6: 1月紹介報酬を再計算 ===' as section;

-- 6-1: 既存の1月紹介報酬をcum_usdtから減算
DO $$
DECLARE
  v_record RECORD;
BEGIN
  FOR v_record IN
    SELECT user_id, SUM(profit_amount) as total_profit
    FROM monthly_referral_profit
    WHERE year_month = '2026-01'
    GROUP BY user_id
  LOOP
    UPDATE affiliate_cycle
    SET
      cum_usdt = cum_usdt - v_record.total_profit,
      updated_at = NOW()
    WHERE user_id = v_record.user_id;
  END LOOP;
  RAISE NOTICE '既存の1月紹介報酬をcum_usdtから減算しました';
END $$;

-- 6-2: 既存の1月紹介報酬レコードを削除
DELETE FROM monthly_referral_profit WHERE year_month = '2026-01';

-- 6-3: 1月紹介報酬を再計算
DO $$
DECLARE
  v_start_date DATE := '2026-01-01';
  v_end_date DATE := '2026-01-31';
  v_year_month TEXT := '2026-01';
  v_user_record RECORD;
  v_child_record RECORD;
  v_total_referral NUMERIC := 0;
  v_level1_rate NUMERIC := 0.20;
  v_level2_rate NUMERIC := 0.10;
  v_level3_rate NUMERIC := 0.05;
BEGIN
  -- 一時テーブル作成
  DROP TABLE IF EXISTS temp_monthly_profit;
  CREATE TEMP TABLE temp_monthly_profit AS
  SELECT
    user_id,
    SUM(daily_profit) as monthly_profit
  FROM nft_daily_profit
  WHERE date >= v_start_date AND date <= v_end_date
  GROUP BY user_id
  HAVING SUM(daily_profit) > 0;

  -- Level 1
  FOR v_user_record IN
    SELECT DISTINCT u.user_id
    FROM users u
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= v_end_date
      AND EXISTS (SELECT 1 FROM users child WHERE child.referrer_user_id = u.user_id)
  LOOP
    FOR v_child_record IN
      SELECT child.user_id as child_user_id, COALESCE(tmp.monthly_profit, 0) as child_monthly_profit
      FROM users child
      LEFT JOIN temp_monthly_profit tmp ON tmp.user_id = child.user_id
      WHERE child.referrer_user_id = v_user_record.user_id
        AND child.has_approved_nft = true
        AND child.operation_start_date IS NOT NULL
        AND child.operation_start_date <= v_end_date
        AND COALESCE(tmp.monthly_profit, 0) > 0
    LOOP
      INSERT INTO monthly_referral_profit (user_id, year_month, referral_level, child_user_id, child_monthly_profit, profit_amount, created_at)
      VALUES (v_user_record.user_id, v_year_month, 1, v_child_record.child_user_id, v_child_record.child_monthly_profit, v_child_record.child_monthly_profit * v_level1_rate, NOW());

      UPDATE affiliate_cycle
      SET cum_usdt = cum_usdt + (v_child_record.child_monthly_profit * v_level1_rate),
          available_usdt = CASE WHEN phase = 'USDT' THEN available_usdt + (v_child_record.child_monthly_profit * v_level1_rate) ELSE available_usdt END,
          updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_referral := v_total_referral + (v_child_record.child_monthly_profit * v_level1_rate);
    END LOOP;
  END LOOP;

  -- Level 2
  FOR v_user_record IN
    SELECT DISTINCT u.user_id FROM users u
    WHERE u.has_approved_nft = true AND u.operation_start_date IS NOT NULL AND u.operation_start_date <= v_end_date
  LOOP
    FOR v_child_record IN
      SELECT child.user_id as child_user_id, COALESCE(tmp.monthly_profit, 0) as child_monthly_profit
      FROM users level1
      JOIN users child ON child.referrer_user_id = level1.user_id
      LEFT JOIN temp_monthly_profit tmp ON tmp.user_id = child.user_id
      WHERE level1.referrer_user_id = v_user_record.user_id
        AND level1.has_approved_nft = true
        AND child.has_approved_nft = true
        AND child.operation_start_date IS NOT NULL AND child.operation_start_date <= v_end_date
        AND COALESCE(tmp.monthly_profit, 0) > 0
    LOOP
      INSERT INTO monthly_referral_profit (user_id, year_month, referral_level, child_user_id, child_monthly_profit, profit_amount, created_at)
      VALUES (v_user_record.user_id, v_year_month, 2, v_child_record.child_user_id, v_child_record.child_monthly_profit, v_child_record.child_monthly_profit * v_level2_rate, NOW());

      UPDATE affiliate_cycle
      SET cum_usdt = cum_usdt + (v_child_record.child_monthly_profit * v_level2_rate),
          available_usdt = CASE WHEN phase = 'USDT' THEN available_usdt + (v_child_record.child_monthly_profit * v_level2_rate) ELSE available_usdt END,
          updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_referral := v_total_referral + (v_child_record.child_monthly_profit * v_level2_rate);
    END LOOP;
  END LOOP;

  -- Level 3
  FOR v_user_record IN
    SELECT DISTINCT u.user_id FROM users u
    WHERE u.has_approved_nft = true AND u.operation_start_date IS NOT NULL AND u.operation_start_date <= v_end_date
  LOOP
    FOR v_child_record IN
      SELECT child.user_id as child_user_id, COALESCE(tmp.monthly_profit, 0) as child_monthly_profit
      FROM users level1
      JOIN users level2 ON level2.referrer_user_id = level1.user_id
      JOIN users child ON child.referrer_user_id = level2.user_id
      LEFT JOIN temp_monthly_profit tmp ON tmp.user_id = child.user_id
      WHERE level1.referrer_user_id = v_user_record.user_id
        AND level1.has_approved_nft = true AND level2.has_approved_nft = true AND child.has_approved_nft = true
        AND child.operation_start_date IS NOT NULL AND child.operation_start_date <= v_end_date
        AND COALESCE(tmp.monthly_profit, 0) > 0
    LOOP
      INSERT INTO monthly_referral_profit (user_id, year_month, referral_level, child_user_id, child_monthly_profit, profit_amount, created_at)
      VALUES (v_user_record.user_id, v_year_month, 3, v_child_record.child_user_id, v_child_record.child_monthly_profit, v_child_record.child_monthly_profit * v_level3_rate, NOW());

      UPDATE affiliate_cycle
      SET cum_usdt = cum_usdt + (v_child_record.child_monthly_profit * v_level3_rate),
          available_usdt = CASE WHEN phase = 'USDT' THEN available_usdt + (v_child_record.child_monthly_profit * v_level3_rate) ELSE available_usdt END,
          updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_referral := v_total_referral + (v_child_record.child_monthly_profit * v_level3_rate);
    END LOOP;
  END LOOP;

  DROP TABLE IF EXISTS temp_monthly_profit;
  RAISE NOTICE '1月紹介報酬再計算完了: 合計 $%', ROUND(v_total_referral::numeric, 2);
END $$;

-- ========================================
-- STEP 7: cum_usdtをmonthly_referral_profitと同期
-- ========================================
SELECT '=== STEP 7: cum_usdtを完全同期 ===' as section;

WITH correct_cum AS (
  SELECT user_id, ROUND(SUM(profit_amount)::numeric, 2) as correct_cum_usdt
  FROM monthly_referral_profit
  GROUP BY user_id
)
UPDATE affiliate_cycle ac
SET
  cum_usdt = COALESCE(cc.correct_cum_usdt, 0),
  updated_at = NOW()
FROM correct_cum cc
WHERE ac.user_id = cc.user_id;

-- 紹介報酬がないユーザーはcum_usdt=0に
UPDATE affiliate_cycle ac
SET cum_usdt = 0, updated_at = NOW()
WHERE NOT EXISTS (SELECT 1 FROM monthly_referral_profit mrp WHERE mrp.user_id = ac.user_id)
  AND ac.cum_usdt != 0;

-- ========================================
-- STEP 8: phaseを再計算
-- ========================================
SELECT '=== STEP 8: phase再計算 ===' as section;

UPDATE affiliate_cycle
SET
  phase = CASE
    WHEN cum_usdt < 1100 THEN 'USDT'
    WHEN (FLOOR(cum_usdt / 1100)::int % 2) = 0 THEN 'USDT'
    ELSE 'HOLD'
  END,
  updated_at = NOW();

-- フェーズ別集計
SELECT phase, COUNT(*) as ユーザー数
FROM affiliate_cycle
GROUP BY phase;

-- ========================================
-- STEP 9: 1月出金データを再作成
-- ========================================
SELECT '=== STEP 9: 1月出金データ再作成 ===' as section;

-- 既存の1月出金データを削除
DELETE FROM monthly_withdrawals WHERE withdrawal_month = '2026-01';

-- 出金データを再作成
INSERT INTO monthly_withdrawals (
  user_id,
  withdrawal_month,
  personal_amount,
  referral_amount,
  total_amount,
  status,
  task_completed,
  withdrawal_method,
  withdrawal_address,
  created_at
)
SELECT
  ac.user_id,
  '2026-01',
  -- personal_amount: 1月の個人利益
  COALESCE((
    SELECT ROUND(SUM(daily_profit)::numeric, 2)
    FROM nft_daily_profit
    WHERE user_id = ac.user_id
      AND date >= '2026-01-01' AND date <= '2026-01-31'
  ), 0),
  -- referral_amount: USDTフェーズなら紹介報酬も含める
  CASE
    WHEN ac.phase = 'USDT' THEN COALESCE((
      SELECT ROUND(SUM(profit_amount)::numeric, 2)
      FROM monthly_referral_profit
      WHERE user_id = ac.user_id AND year_month = '2026-01'
    ), 0)
    ELSE 0
  END,
  -- total_amount
  COALESCE((
    SELECT ROUND(SUM(daily_profit)::numeric, 2)
    FROM nft_daily_profit
    WHERE user_id = ac.user_id
      AND date >= '2026-01-01' AND date <= '2026-01-31'
  ), 0) +
  CASE
    WHEN ac.phase = 'USDT' THEN COALESCE((
      SELECT ROUND(SUM(profit_amount)::numeric, 2)
      FROM monthly_referral_profit
      WHERE user_id = ac.user_id AND year_month = '2026-01'
    ), 0)
    ELSE 0
  END,
  'pending',
  false,
  'coinw',
  u.coinw_uid,
  NOW()
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-31'
  AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
  AND (
    CASE
      WHEN ac.phase = 'USDT' THEN ac.available_usdt + (ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))
      ELSE ac.available_usdt
    END
  ) >= 10;

SELECT '1月出金データ作成件数: ' || COUNT(*) as info FROM monthly_withdrawals WHERE withdrawal_month = '2026-01';

-- ========================================
-- STEP 10: 最終確認
-- ========================================
SELECT '=== STEP 10: 最終確認 ===' as section;

-- 0D4493の確認
SELECT
  '0D4493の最終状態' as info,
  (SELECT ROUND(SUM(daily_profit)::numeric, 3) FROM nft_daily_profit
   WHERE user_id = '0D4493' AND date >= '2026-01-01' AND date <= '2026-01-31') as 個人利益,
  (SELECT ROUND(SUM(profit_amount)::numeric, 3) FROM monthly_referral_profit
   WHERE user_id = '0D4493' AND year_month = '2026-01') as 紹介報酬,
  ac.cum_usdt,
  ac.phase,
  ac.available_usdt
FROM affiliate_cycle ac
WHERE ac.user_id = '0D4493';

-- 1月サマリー
SELECT
  '1月サマリー' as info,
  (SELECT ROUND(SUM(distribution_dividend)::numeric, 2) FROM daily_yield_log_v2
   WHERE date >= '2026-01-01' AND date <= '2026-01-31') as 配当合計,
  (SELECT ROUND(SUM(profit_amount)::numeric, 2) FROM monthly_referral_profit
   WHERE year_month = '2026-01') as 紹介報酬合計,
  (SELECT COUNT(*) FROM monthly_withdrawals WHERE withdrawal_month = '2026-01') as 出金対象者数;

-- 不整合チェック
SELECT '=== 不整合チェック ===' as section;
WITH correct_cum AS (
  SELECT user_id, ROUND(SUM(profit_amount)::numeric, 2) as correct_cum_usdt
  FROM monthly_referral_profit
  GROUP BY user_id
)
SELECT COUNT(*) as cum_usdt不整合件数
FROM affiliate_cycle ac
LEFT JOIN correct_cum cc ON ac.user_id = cc.user_id
WHERE ABS(COALESCE(cc.correct_cum_usdt, 0) - ac.cum_usdt) > 0.01;
