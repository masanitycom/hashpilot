-- process_daily_yield_v2関数から日次紹介報酬の処理を削除
-- 紹介報酬は月次のみ（月末処理で計算）

CREATE OR REPLACE FUNCTION process_daily_yield_v2(
  p_date DATE,
  p_total_profit_amount NUMERIC,
  p_is_test_mode BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(
  status TEXT,
  message TEXT,
  details JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
  v_total_stock NUMERIC := 0;
  v_auto_nft_count INTEGER := 0;
BEGIN
  -- 入力チェック
  IF p_date IS NULL THEN
    RETURN QUERY SELECT 'ERROR'::TEXT, '日付が指定されていません'::TEXT, NULL::JSONB;
    RETURN;
  END IF;

  IF p_total_profit_amount IS NULL THEN
    RETURN QUERY SELECT 'ERROR'::TEXT, '運用利益が指定されていません'::TEXT, NULL::JSONB;
    RETURN;
  END IF;

  -- 重複チェック
  IF EXISTS (SELECT 1 FROM daily_yield_log_v2 WHERE date = p_date) THEN
    IF NOT p_is_test_mode THEN
      RETURN QUERY SELECT 'ERROR'::TEXT,
        format('日付 %s の日利データは既に存在します', p_date)::TEXT,
        NULL::JSONB;
      RETURN;
    ELSE
      -- テストモード：既存データを削除
      DELETE FROM daily_yield_log_v2 WHERE date = p_date;
      DELETE FROM nft_daily_profit WHERE date = p_date;
      DELETE FROM stock_fund WHERE date = p_date;
    END IF;
  END IF;

  -- 運用中のNFT数を取得
  SELECT COUNT(*)
  INTO v_total_nft_count
  FROM nft_master nm
  JOIN users u ON nm.user_id = u.user_id
  WHERE nm.buyback_date IS NULL
    AND u.operation_start_date IS NOT NULL
    AND u.operation_start_date <= p_date
    AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

  IF v_total_nft_count = 0 THEN
    RETURN QUERY SELECT 'ERROR'::TEXT, '運用中のNFTが見つかりません'::TEXT, NULL::JSONB;
    RETURN;
  END IF;

  -- 1NFTあたりの利益を計算
  v_profit_per_nft := p_total_profit_amount / v_total_nft_count;

  -- 前日の累積値を取得
  SELECT
    cumulative_gross_profit,
    cumulative_net_profit
  INTO
    v_prev_cumulative_gross,
    v_prev_cumulative_net
  FROM daily_yield_log_v2
  WHERE date < p_date
  ORDER BY date DESC
  LIMIT 1;

  v_prev_cumulative_gross := COALESCE(v_prev_cumulative_gross, 0);
  v_prev_cumulative_net := COALESCE(v_prev_cumulative_net, 0);

  -- 累積計算
  v_cumulative_gross := v_prev_cumulative_gross + p_total_profit_amount;
  v_cumulative_fee := v_fee_rate * GREATEST(v_cumulative_gross, 0);
  v_cumulative_net := v_cumulative_gross - v_cumulative_fee;
  v_daily_pnl := v_cumulative_net - v_prev_cumulative_net;

  -- 配分計算
  v_distribution_dividend := v_daily_pnl * 0.60;
  v_distribution_affiliate := v_daily_pnl * 0.30;  -- 月末に配布
  v_distribution_stock := v_daily_pnl * 0.10;

  -- daily_yield_log_v2にログを記録
  INSERT INTO daily_yield_log_v2 (
    date,
    total_profit_amount,
    total_nft_count,
    profit_per_nft,
    cumulative_gross_profit,
    fee_rate,
    cumulative_fee,
    cumulative_net_profit,
    daily_pnl,
    distribution_dividend,
    distribution_affiliate,
    distribution_stock,
    is_month_end,
    created_by
  ) VALUES (
    p_date,
    p_total_profit_amount,
    v_total_nft_count,
    v_profit_per_nft,
    v_cumulative_gross,
    v_fee_rate,
    v_cumulative_fee,
    v_cumulative_net,
    v_daily_pnl,
    v_distribution_dividend,
    v_distribution_affiliate,
    v_distribution_stock,
    EXTRACT(DAY FROM (p_date + INTERVAL '1 day')) = 1,
    current_user
  );

  -- STEP 1: 個人利益の配布（60%）
  IF v_distribution_dividend != 0 THEN
    FOR v_user_record IN
      SELECT
        u.user_id,
        u.id as user_uuid,
        COUNT(nm.id) as nft_count
      FROM users u
      JOIN nft_master nm ON nm.user_id = u.user_id
      WHERE nm.buyback_date IS NULL
        AND u.operation_start_date IS NOT NULL
        AND u.operation_start_date <= p_date
        AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
      GROUP BY u.user_id, u.id
    LOOP
      v_user_profit := (v_distribution_dividend / v_total_nft_count) * v_user_record.nft_count;

      -- NFTごとに利益を記録
      FOR v_nft_record IN
        SELECT id as nft_id
        FROM nft_master
        WHERE user_id = v_user_record.user_id
          AND buyback_date IS NULL
      LOOP
        INSERT INTO nft_daily_profit (
          nft_id,
          user_id,
          date,
          daily_profit,
          yield_rate,
          user_rate,
          base_amount,
          phase,
          created_at
        ) VALUES (
          v_nft_record.nft_id,
          v_user_record.user_id,
          p_date,
          v_user_profit / v_user_record.nft_count,
          NULL,
          NULL,
          1000,
          'DIVIDEND',
          NOW()
        );
      END LOOP;

      -- available_usdtに加算（個人利益のみ）
      UPDATE affiliate_cycle
      SET
        available_usdt = available_usdt + v_user_profit,
        updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_distributed := v_total_distributed + v_user_profit;
    END LOOP;
  END IF;

  -- ※紹介報酬（30%）は月末に月次処理で計算・配布
  -- ※日次では紹介報酬を処理しない

  -- STEP 2: NFT自動付与（cum_usdt >= 2200の場合）
  FOR v_user_record IN
    SELECT
      u.user_id,
      u.id as user_uuid,
      ac.cum_usdt,
      ac.auto_nft_count
    FROM users u
    JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE ac.cum_usdt >= 2200
  LOOP
    -- 新しいNFTを作成
    INSERT INTO nft_master (
      user_id,
      nft_type,
      acquired_date,
      buyback_date
    ) VALUES (
      v_user_record.user_id,
      'auto',
      p_date,
      NULL
    );

    -- 購入履歴を作成
    INSERT INTO purchases (
      user_id,
      nft_type,
      usdt_amount,
      payment_tx_id,
      payment_method,
      admin_approved,
      admin_approved_at,
      cycle_number_at_purchase,
      purchase_date
    ) VALUES (
      v_user_record.user_id,
      'auto',
      1100,
      'AUTO_' || p_date || '_' || v_user_record.user_id,
      'cycle_reward',
      true,
      NOW(),
      v_user_record.auto_nft_count + 1,
      p_date
    );

    -- affiliate_cycleを更新
    UPDATE affiliate_cycle
    SET
      cum_usdt = cum_usdt - 1100,
      available_usdt = available_usdt + 1100,
      auto_nft_count = auto_nft_count + 1,
      total_nft_count = total_nft_count + 1,
      phase = CASE WHEN (cum_usdt - 1100) >= 1100 THEN 'HOLD' ELSE 'USDT' END,
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id;

    -- ユーザーのNFTフラグを更新
    UPDATE users
    SET
      has_approved_nft = true,
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id;

    v_auto_nft_count := v_auto_nft_count + 1;
  END LOOP;

  -- STEP 3: ストック資金の配布（10%）
  IF v_distribution_stock != 0 THEN
    FOR v_user_record IN
      SELECT
        u.user_id,
        COUNT(nm.id) as nft_count
      FROM users u
      JOIN nft_master nm ON nm.user_id = u.user_id
      WHERE nm.buyback_date IS NULL
        AND u.operation_start_date IS NOT NULL
        AND u.operation_start_date <= p_date
        AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
      GROUP BY u.user_id
    LOOP
      v_user_profit := (v_distribution_stock / v_total_nft_count) * v_user_record.nft_count;

      INSERT INTO stock_fund (
        user_id,
        date,
        stock_amount,
        cumulative_stock,
        source,
        notes
      )
      SELECT
        v_user_record.user_id,
        p_date,
        v_user_profit,
        COALESCE((SELECT cumulative_stock FROM stock_fund
                  WHERE user_id = v_user_record.user_id
                  ORDER BY date DESC LIMIT 1), 0) + v_user_profit,
        'daily_distribution',
        format('日利配分（%s）', p_date);

      v_total_stock := v_total_stock + v_user_profit;
    END LOOP;
  END IF;

  -- 整合性チェック
  IF ABS((v_cumulative_net + v_cumulative_fee) - v_cumulative_gross) > 0.01 THEN
    RAISE WARNING '整合性エラー: N_d + F_d != G_d';
  END IF;

  -- 結果を返す
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
        'total_stock', v_total_stock,
        'auto_nft_count', v_auto_nft_count
      ),
      'note', '紹介報酬は月末に月次処理で配布'
    );

EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT
      'ERROR'::TEXT,
      format('エラー: %s', SQLERRM)::TEXT,
      jsonb_build_object('error_detail', SQLERRM);
END;
$$;

-- 確認
SELECT 'process_daily_yield_v2関数を修正しました（日次紹介報酬を削除）' as result;
