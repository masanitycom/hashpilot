/* ========================================
   RPC関数の修正: テストモード対応
   ======================================== */

CREATE OR REPLACE FUNCTION process_daily_yield_v2(
  p_date DATE,
  p_total_profit_amount NUMERIC,
  p_is_test_mode BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(
  status TEXT,
  message TEXT,
  details JSONB
) AS $$
DECLARE
  v_total_nft_count INTEGER;
  v_profit_per_nft NUMERIC;
  v_prev_cumulative_gross NUMERIC := 0;
  v_prev_cumulative_net NUMERIC := 0;
  v_cumulative_gross NUMERIC;
  v_cumulative_fee NUMERIC;
  v_cumulative_net NUMERIC;
  v_daily_pnl NUMERIC;
  v_distribution_dividend NUMERIC;
  v_distribution_affiliate NUMERIC;
  v_distribution_stock NUMERIC;
  v_fee_rate NUMERIC := 0.30;
  v_user_record RECORD;
  v_nft_record RECORD;
  v_user_profit NUMERIC;
  v_total_distributed NUMERIC := 0;
  v_total_affiliate NUMERIC := 0;
  v_total_stock NUMERIC := 0;
BEGIN
  IF p_date IS NULL THEN
    RETURN QUERY SELECT 'ERROR'::TEXT, '日付が指定されていません'::TEXT, NULL::JSONB;
    RETURN;
  END IF;

  IF p_total_profit_amount IS NULL THEN
    RETURN QUERY SELECT 'ERROR'::TEXT, '運用利益が指定されていません'::TEXT, NULL::JSONB;
    RETURN;
  END IF;

  IF EXISTS (SELECT 1 FROM daily_yield_log_v2 WHERE date = p_date) THEN
    IF NOT p_is_test_mode THEN
      RETURN QUERY SELECT 'ERROR'::TEXT,
        format('日付 %s の日利データは既に存在します', p_date)::TEXT,
        NULL::JSONB;
      RETURN;
    ELSE
      DELETE FROM daily_yield_log_v2 WHERE date = p_date;
      DELETE FROM nft_daily_profit WHERE date = p_date;
      DELETE FROM user_referral_profit WHERE date = p_date;
      DELETE FROM stock_fund WHERE date = p_date;
    END IF;
  END IF;

  /* テストモードでは operation_start_date チェックを緩和 */
  IF p_is_test_mode THEN
    SELECT COUNT(*)
    INTO v_total_nft_count
    FROM nft_master nm
    WHERE nm.buyback_date IS NULL;
  ELSE
    SELECT COUNT(*)
    INTO v_total_nft_count
    FROM nft_master nm
    JOIN users u ON nm.user_id = u.user_id
    WHERE nm.buyback_date IS NULL
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= p_date
      AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);
  END IF;

  IF v_total_nft_count = 0 THEN
    RETURN QUERY SELECT 'ERROR'::TEXT, '運用中のNFTが見つかりません'::TEXT, NULL::JSONB;
    RETURN;
  END IF;

  v_profit_per_nft := p_total_profit_amount / v_total_nft_count;

  RAISE NOTICE '📊 入力値:';
  RAISE NOTICE '  全体運用利益: $%', p_total_profit_amount;
  RAISE NOTICE '  全NFT数: %個', v_total_nft_count;
  RAISE NOTICE '  1 NFTあたり: $%', v_profit_per_nft;

  SELECT cumulative_gross_profit, cumulative_net_profit
  INTO v_prev_cumulative_gross, v_prev_cumulative_net
  FROM daily_yield_log_v2
  WHERE date < p_date
  ORDER BY date DESC
  LIMIT 1;

  v_prev_cumulative_gross := COALESCE(v_prev_cumulative_gross, 0);
  v_prev_cumulative_net := COALESCE(v_prev_cumulative_net, 0);

  v_cumulative_gross := v_prev_cumulative_gross + p_total_profit_amount;
  v_cumulative_fee := v_fee_rate * GREATEST(v_cumulative_gross, 0);
  v_cumulative_net := v_cumulative_gross - v_cumulative_fee;
  v_daily_pnl := v_cumulative_net - v_prev_cumulative_net;

  RAISE NOTICE '';
  RAISE NOTICE '📊 累積計算:';
  RAISE NOTICE '  G_d (累積利益・手数料前): $%', v_cumulative_gross;
  RAISE NOTICE '  F_d (手数料累積): $%', v_cumulative_fee;
  RAISE NOTICE '  N_d (顧客累積利益): $%', v_cumulative_net;
  RAISE NOTICE '  ΔN_d (当日確定PNL): $%', v_daily_pnl;

  IF v_daily_pnl > 0 THEN
    v_distribution_dividend := v_daily_pnl * 0.60;
    v_distribution_affiliate := v_daily_pnl * 0.30;
    v_distribution_stock := v_daily_pnl * 0.10;
  ELSE
    v_distribution_dividend := 0;
    v_distribution_affiliate := 0;
    v_distribution_stock := 0;
  END IF;

  RAISE NOTICE '';
  RAISE NOTICE '📊 分配計算:';
  RAISE NOTICE '  配当 (60%%): $%', v_distribution_dividend;
  RAISE NOTICE '  アフィリ (30%%): $%', v_distribution_affiliate;
  RAISE NOTICE '  ストック (10%%): $%', v_distribution_stock;

  INSERT INTO daily_yield_log_v2 (
    date, total_profit_amount, total_nft_count, profit_per_nft,
    cumulative_gross_profit, fee_rate, cumulative_fee, cumulative_net_profit, daily_pnl,
    distribution_dividend, distribution_affiliate, distribution_stock,
    is_month_end, created_by
  ) VALUES (
    p_date, p_total_profit_amount, v_total_nft_count, v_profit_per_nft,
    v_cumulative_gross, v_fee_rate, v_cumulative_fee, v_cumulative_net, v_daily_pnl,
    v_distribution_dividend, v_distribution_affiliate, v_distribution_stock,
    EXTRACT(DAY FROM (p_date + INTERVAL '1 day')) = 1, current_user
  );

  /* テストモードでは配当配分をスキップ（daily_yield_log_v2のみ記録） */
  IF NOT p_is_test_mode AND v_distribution_dividend > 0 THEN
    FOR v_user_record IN
      SELECT u.user_id, u.id as user_uuid, COUNT(nm.id) as nft_count
      FROM users u
      JOIN nft_master nm ON nm.user_id = u.user_id
      WHERE nm.buyback_date IS NULL
        AND u.operation_start_date IS NOT NULL
        AND u.operation_start_date <= p_date
        AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
      GROUP BY u.user_id, u.id
    LOOP
      v_user_profit := (v_distribution_dividend / v_total_nft_count) * v_user_record.nft_count;

      FOR v_nft_record IN
        SELECT id as nft_id
        FROM nft_master
        WHERE user_id = v_user_record.user_id AND buyback_date IS NULL
      LOOP
        INSERT INTO nft_daily_profit (
          nft_id, user_id, date, daily_profit,
          yield_rate, user_rate, base_amount, phase, created_at
        ) VALUES (
          v_nft_record.nft_id, v_user_record.user_id, p_date,
          v_user_profit / v_user_record.nft_count,
          NULL, NULL, 1000, 'DIVIDEND', NOW()
        );
      END LOOP;

      UPDATE affiliate_cycle
      SET available_usdt = available_usdt + v_user_profit, updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_distributed := v_total_distributed + v_user_profit;
    END LOOP;
  END IF;

  IF v_distribution_affiliate > 0 THEN
    v_total_affiliate := v_distribution_affiliate;
  END IF;

  /* テストモードではストック配分をスキップ */
  IF NOT p_is_test_mode AND v_distribution_stock > 0 THEN
    FOR v_user_record IN
      SELECT u.user_id, COUNT(nm.id) as nft_count
      FROM users u
      JOIN nft_master nm ON nm.user_id = u.user_id
      WHERE nm.buyback_date IS NULL
        AND u.operation_start_date IS NOT NULL
        AND u.operation_start_date <= p_date
        AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
      GROUP BY u.user_id
    LOOP
      v_user_profit := (v_distribution_stock / v_total_nft_count) * v_user_record.nft_count;

      INSERT INTO stock_fund (user_id, date, stock_amount, cumulative_stock, source, notes)
      SELECT
        v_user_record.user_id, p_date, v_user_profit,
        COALESCE((SELECT cumulative_stock FROM stock_fund
                  WHERE user_id = v_user_record.user_id
                  ORDER BY date DESC LIMIT 1), 0) + v_user_profit,
        'daily_distribution', format('日利配分（%s）', p_date);

      v_total_stock := v_total_stock + v_user_profit;
    END LOOP;
  END IF;

  IF ABS((v_cumulative_net + v_cumulative_fee) - v_cumulative_gross) > 0.01 THEN
    RAISE WARNING '⚠️ 整合性エラー: N_d + F_d != G_d';
    RAISE WARNING '  N_d: $%, F_d: $%, G_d: $%', v_cumulative_net, v_cumulative_fee, v_cumulative_gross;
  END IF;

  RETURN QUERY SELECT
    'SUCCESS'::TEXT,
    format('日利計算完了: %s', p_date)::TEXT,
    jsonb_build_object(
      'date', p_date,
      'input', jsonb_build_object(
        'total_profit_amount', p_total_profit_amount,
        'total_nft_count', v_total_nft_count,
        'profit_per_nft', v_profit_per_nft
      ),
      'cumulative', jsonb_build_object(
        'G_d', v_cumulative_gross,
        'F_d', v_cumulative_fee,
        'N_d', v_cumulative_net,
        'ΔN_d', v_daily_pnl
      ),
      'distribution', jsonb_build_object(
        'dividend', v_distribution_dividend,
        'affiliate', v_distribution_affiliate,
        'stock', v_distribution_stock,
        'total_distributed', v_total_distributed,
        'total_affiliate', v_total_affiliate,
        'total_stock', v_total_stock
      )
    );

EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT 'ERROR'::TEXT,
      format('エラー: %s', SQLERRM)::TEXT,
      jsonb_build_object('error_detail', SQLERRM);
END;
$$ LANGUAGE plpgsql;
