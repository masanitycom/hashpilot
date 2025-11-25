/* ========================================
   日利計算v2のシミュレーションテスト
   ======================================== */

/* テストデータのクリア */
DELETE FROM daily_yield_log_v2 WHERE date >= '2025-01-01' AND date <= '2025-01-31';
DELETE FROM nft_daily_profit WHERE date >= '2025-01-01' AND date <= '2025-01-31';
DELETE FROM user_referral_profit WHERE date >= '2025-01-01' AND date <= '2025-01-31';
DELETE FROM stock_fund WHERE date >= '2025-01-01' AND date <= '2025-01-31';

/* ========================================
   ケース1: プラス・マイナス混在 → 最終プラス
   P = [+100, -50, +120, -60, +80, -40, +70]
   ======================================== */

DO $$
DECLARE
  v_test_profits NUMERIC[] := ARRAY[100, -50, 120, -60, 80, -40, 70];
  v_date DATE;
  v_day INTEGER;
BEGIN
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE 'ケース1: プラス・マイナス混在 → 最終プラス';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '';
  RAISE NOTICE '期待値（設計書より）:';
  RAISE NOTICE '日   P_d    G_d    F_d    N_d    ΔN_d';
  RAISE NOTICE '1   +100   100    30     70     +70';
  RAISE NOTICE '2   −50    50     15     35     −35';
  RAISE NOTICE '3   +120   170    51     119    +84';
  RAISE NOTICE '4   −60    110    33     77     −42';
  RAISE NOTICE '5   +80    190    57     133    +56';
  RAISE NOTICE '6   −40    150    45     105    −28';
  RAISE NOTICE '7   +70    220    66     154    +49';
  RAISE NOTICE '';
  RAISE NOTICE '実際の計算結果:';
  RAISE NOTICE '';

  FOR v_day IN 1..7 LOOP
    v_date := '2025-01-01'::DATE + (v_day - 1);
    PERFORM process_daily_yield_v2(v_date, v_test_profits[v_day], TRUE);
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;

/* 結果確認 */
SELECT
  EXTRACT(DAY FROM date)::INTEGER as 日,
  total_profit_amount as "P_d",
  cumulative_gross_profit as "G_d",
  cumulative_fee as "F_d",
  cumulative_net_profit as "N_d",
  daily_pnl as "ΔN_d"
FROM daily_yield_log_v2
WHERE date >= '2025-01-01' AND date <= '2025-01-07'
ORDER BY date;

/* 整合性チェック */
DO $$
DECLARE
  v_final RECORD;
  v_sum_daily_pnl NUMERIC;
BEGIN
  SELECT cumulative_gross_profit, cumulative_fee, cumulative_net_profit
  INTO v_final
  FROM daily_yield_log_v2
  WHERE date = '2025-01-07';

  SELECT SUM(daily_pnl) INTO v_sum_daily_pnl
  FROM daily_yield_log_v2
  WHERE date >= '2025-01-01' AND date <= '2025-01-07';

  RAISE NOTICE '';
  RAISE NOTICE '整合性チェック:';
  RAISE NOTICE '  G_final = %', v_final.cumulative_gross_profit;
  RAISE NOTICE '  Fee_final = %', v_final.cumulative_fee;
  RAISE NOTICE '  N_final = %', v_final.cumulative_net_profit;
  RAISE NOTICE '  N_final + Fee_final = % (should be % = G_final)',
    v_final.cumulative_net_profit + v_final.cumulative_fee,
    v_final.cumulative_gross_profit;
  RAISE NOTICE '  Σ ΔN_d = % (should be % = N_final)',
    v_sum_daily_pnl,
    v_final.cumulative_net_profit;

  IF ABS((v_final.cumulative_net_profit + v_final.cumulative_fee) - v_final.cumulative_gross_profit) < 0.01 THEN
    RAISE NOTICE '  ✅ N_final + Fee_final = G_final';
  ELSE
    RAISE WARNING '  ❌ 整合性エラー';
  END IF;

  IF ABS(v_sum_daily_pnl - v_final.cumulative_net_profit) < 0.01 THEN
    RAISE NOTICE '  ✅ Σ ΔN_d = N_final';
  ELSE
    RAISE WARNING '  ❌ 整合性エラー';
  END IF;
END $$;

/* ========================================
   ケース2: プラス・マイナス混在 → 最終マイナス
   P = [+80, -120, +50, -60, -40, -30, -20]
   ======================================== */

DELETE FROM daily_yield_log_v2 WHERE date >= '2025-02-01' AND date <= '2025-02-28';
DELETE FROM nft_daily_profit WHERE date >= '2025-02-01' AND date <= '2025-02-28';
DELETE FROM user_referral_profit WHERE date >= '2025-02-01' AND date <= '2025-02-28';
DELETE FROM stock_fund WHERE date >= '2025-02-01' AND date <= '2025-02-28';

DO $$
DECLARE
  v_test_profits NUMERIC[] := ARRAY[80, -120, 50, -60, -40, -30, -20];
  v_date DATE;
  v_day INTEGER;
BEGIN
  RAISE NOTICE '';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE 'ケース2: プラス・マイナス混在 → 最終マイナス';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
  RAISE NOTICE '';
  RAISE NOTICE '期待値（設計書より）:';
  RAISE NOTICE '日   P_d     G_d     F_d    N_d     ΔN_d';
  RAISE NOTICE '1   +80     80      24     56      +56';
  RAISE NOTICE '2   −120    −40     0      −40     −96';
  RAISE NOTICE '3   +50     10      3      7       +47';
  RAISE NOTICE '4   −60     −50     0      −50     −57';
  RAISE NOTICE '5   −40     −90     0      −90     −40';
  RAISE NOTICE '6   −30     −120    0      −120    −30';
  RAISE NOTICE '7   −20     −140    0      −140    −20';
  RAISE NOTICE '';
  RAISE NOTICE '実際の計算結果:';
  RAISE NOTICE '';

  FOR v_day IN 1..7 LOOP
    v_date := '2025-02-01'::DATE + (v_day - 1);
    PERFORM process_daily_yield_v2(v_date, v_test_profits[v_day], TRUE);
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;

/* 結果確認 */
SELECT
  EXTRACT(DAY FROM date)::INTEGER as 日,
  total_profit_amount as "P_d",
  cumulative_gross_profit as "G_d",
  cumulative_fee as "F_d",
  cumulative_net_profit as "N_d",
  daily_pnl as "ΔN_d"
FROM daily_yield_log_v2
WHERE date >= '2025-02-01' AND date <= '2025-02-07'
ORDER BY date;

/* 整合性チェック */
DO $$
DECLARE
  v_final RECORD;
  v_sum_daily_pnl NUMERIC;
BEGIN
  SELECT cumulative_gross_profit, cumulative_fee, cumulative_net_profit
  INTO v_final
  FROM daily_yield_log_v2
  WHERE date = '2025-02-07';

  SELECT SUM(daily_pnl) INTO v_sum_daily_pnl
  FROM daily_yield_log_v2
  WHERE date >= '2025-02-01' AND date <= '2025-02-07';

  RAISE NOTICE '';
  RAISE NOTICE '整合性チェック:';
  RAISE NOTICE '  G_final = %', v_final.cumulative_gross_profit;
  RAISE NOTICE '  Fee_final = %', v_final.cumulative_fee;
  RAISE NOTICE '  N_final = %', v_final.cumulative_net_profit;
  RAISE NOTICE '  N_final + Fee_final = % (should be % = G_final)',
    v_final.cumulative_net_profit + v_final.cumulative_fee,
    v_final.cumulative_gross_profit;
  RAISE NOTICE '  Σ ΔN_d = % (should be % = N_final)',
    v_sum_daily_pnl,
    v_final.cumulative_net_profit;

  IF ABS((v_final.cumulative_net_profit + v_final.cumulative_fee) - v_final.cumulative_gross_profit) < 0.01 THEN
    RAISE NOTICE '  ✅ N_final + Fee_final = G_final';
  ELSE
    RAISE WARNING '  ❌ 整合性エラー';
  END IF;

  IF ABS(v_sum_daily_pnl - v_final.cumulative_net_profit) < 0.01 THEN
    RAISE NOTICE '  ✅ Σ ΔN_d = N_final';
  ELSE
    RAISE WARNING '  ❌ 整合性エラー';
  END IF;
END $$;

/* 分配の確認 */
SELECT
  date,
  daily_pnl as "ΔN_d",
  distribution_dividend as "配当(60%)",
  distribution_affiliate as "アフィリ(30%)",
  distribution_stock as "ストック(10%)",
  (distribution_dividend + distribution_affiliate + distribution_stock) as "合計"
FROM daily_yield_log_v2
WHERE date >= '2025-01-01' AND date <= '2025-02-07'
ORDER BY date;
