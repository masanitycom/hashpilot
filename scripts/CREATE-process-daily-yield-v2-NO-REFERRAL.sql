-- ========================================
-- V2日利処理関数（紹介報酬計算なし版）
-- ========================================
--
-- 変更内容:
-- - 紹介報酬の計算を完全に削除
-- - 日利配布とNFT自動付与のみ実行
-- - 紹介報酬は月末に別関数で計算
--
-- 作成日: 2025-12-01
-- ========================================

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
  v_user_nft_count INTEGER;
  v_total_distributed NUMERIC := 0;
  v_total_stock NUMERIC := 0;
  v_auto_nft_count INTEGER := 0;
BEGIN
  -- ========================================
  -- STEP 1: 入力検証
  -- ========================================
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
      RETURN QUERY SELECT 'ERROR'::TEXT, 'この日付の日利は既に設定されています'::TEXT, NULL::JSONB;
      RETURN;
    END IF;
  END IF;

  -- ========================================
  -- STEP 2: 運用中のNFT総数を取得
  -- ========================================
  SELECT COUNT(*)
  INTO v_total_nft_count
  FROM nft_master nm
  INNER JOIN users u ON nm.user_id = u.user_id
  WHERE nm.buyback_date IS NULL
    AND u.has_approved_nft = true
    AND u.operation_start_date IS NOT NULL
    AND u.operation_start_date <= p_date;

  IF v_total_nft_count = 0 THEN
    RETURN QUERY SELECT 'ERROR'::TEXT, '運用中のNFTがありません'::TEXT, NULL::JSONB;
    RETURN;
  END IF;

  -- ========================================
  -- STEP 3: 1 NFTあたりの利益を計算
  -- ========================================
  v_profit_per_nft := p_total_profit_amount / v_total_nft_count;

  -- ========================================
  -- STEP 4: 前日の累積値を取得
  -- ========================================
  SELECT
    COALESCE(cumulative_gross, 0),
    COALESCE(cumulative_net, 0)
  INTO v_prev_cumulative_gross, v_prev_cumulative_net
  FROM daily_yield_log_v2
  WHERE date < p_date
  ORDER BY date DESC
  LIMIT 1;

  -- ========================================
  -- STEP 5: 累積値を計算
  -- ========================================
  v_cumulative_gross := v_prev_cumulative_gross + p_total_profit_amount;
  v_cumulative_fee := v_cumulative_gross * v_fee_rate;
  v_cumulative_net := v_cumulative_gross - v_cumulative_fee;

  -- ========================================
  -- STEP 6: 当日のP&Lを計算
  -- ========================================
  v_daily_pnl := v_cumulative_net - v_prev_cumulative_net;

  -- ========================================
  -- STEP 7: 配分を計算
  -- ========================================
  v_distribution_dividend := v_daily_pnl * 0.60;   -- 配当60%
  v_distribution_affiliate := v_daily_pnl * 0.30;  -- 紹介報酬30%（月末に計算）
  v_distribution_stock := v_daily_pnl * 0.10;      -- ストック10%

  -- ========================================
  -- STEP 8: ログを記録（テストモードでは削除してから挿入）
  -- ========================================
  IF p_is_test_mode THEN
    DELETE FROM daily_yield_log_v2 WHERE date = p_date;
  END IF;

  INSERT INTO daily_yield_log_v2 (
    date,
    daily_pnl,
    total_nft_count,
    profit_per_nft,
    cumulative_gross,
    cumulative_fee,
    cumulative_net,
    distribution_dividend,
    distribution_affiliate,
    distribution_stock,
    created_at
  ) VALUES (
    p_date,
    p_total_profit_amount,
    v_total_nft_count,
    v_profit_per_nft,
    v_cumulative_gross,
    v_cumulative_fee,
    v_cumulative_net,
    v_distribution_dividend,
    v_distribution_affiliate,
    v_distribution_stock,
    NOW()
  );

  -- ========================================
  -- STEP 9: 個人利益の配布（配当60%）
  -- ========================================
  IF v_distribution_dividend != 0 THEN
    -- 既存のレコードを削除（再実行時）
    IF p_is_test_mode THEN
      DELETE FROM nft_daily_profit WHERE date = p_date;
      DELETE FROM user_daily_profit WHERE date = p_date;
    END IF;

    -- ユーザーごとに集計して配布
    FOR v_user_record IN
      SELECT
        u.user_id,
        u.is_pegasus_exchange,
        COUNT(nm.id) as nft_count
      FROM users u
      INNER JOIN nft_master nm ON u.user_id = nm.user_id
      WHERE nm.buyback_date IS NULL
        AND u.has_approved_nft = true
        AND u.operation_start_date IS NOT NULL
        AND u.operation_start_date <= p_date
      GROUP BY u.user_id, u.is_pegasus_exchange
    LOOP
      -- ペガサス交換ユーザーは個人利益なし
      IF v_user_record.is_pegasus_exchange = TRUE THEN
        CONTINUE;
      END IF;

      v_user_profit := v_profit_per_nft * v_user_record.nft_count;

      -- user_daily_profitに記録
      INSERT INTO user_daily_profit (
        user_id,
        date,
        daily_profit,
        phase,
        created_at
      ) VALUES (
        v_user_record.user_id,
        p_date,
        v_user_profit,
        'DIVIDEND',
        NOW()
      );

      -- nft_daily_profitに記録（各NFTごと）
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

      -- affiliate_cycleのavailable_usdtに加算
      UPDATE affiliate_cycle
      SET
        available_usdt = available_usdt + v_user_profit,
        updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_distributed := v_total_distributed + v_user_profit;
    END LOOP;
  END IF;

  -- ========================================
  -- STEP 10: 紹介報酬の配布（削除）
  -- ========================================
  -- 紹介報酬は月末に別関数 process_monthly_referral_reward() で計算

  -- ========================================
  -- STEP 11: NFT自動付与（ストック10%）
  -- ========================================
  IF v_distribution_stock > 0 THEN
    -- cum_usdtにストック資金を加算
    UPDATE affiliate_cycle
    SET
      cum_usdt = cum_usdt + (v_profit_per_nft * (
        SELECT COUNT(*)
        FROM nft_master nm
        WHERE nm.user_id = affiliate_cycle.user_id
          AND nm.buyback_date IS NULL
      ) * 0.10),
      updated_at = NOW()
    WHERE user_id IN (
      SELECT DISTINCT u.user_id
      FROM users u
      INNER JOIN nft_master nm ON u.user_id = nm.user_id
      WHERE nm.buyback_date IS NULL
        AND u.has_approved_nft = true
        AND u.operation_start_date IS NOT NULL
        AND u.operation_start_date <= p_date
    );

    -- cum_usdt >= 2200のユーザーにNFT自動付与
    FOR v_user_record IN
      SELECT
        ac.user_id,
        ac.cum_usdt,
        ac.auto_nft_count
      FROM affiliate_cycle ac
      INNER JOIN users u ON ac.user_id = u.user_id
      WHERE ac.cum_usdt >= 2200
        AND u.has_approved_nft = true
        AND u.operation_start_date IS NOT NULL
        AND u.operation_start_date <= p_date
    LOOP
      -- NFT自動付与
      INSERT INTO nft_master (
        user_id,
        nft_type,
        acquired_date,
        nft_value,
        created_at
      ) VALUES (
        v_user_record.user_id,
        'auto',
        p_date,
        1000,
        NOW()
      );

      -- purchasesテーブルにも記録
      INSERT INTO purchases (
        user_id,
        purchase_date,
        amount_usd,
        is_auto_purchase,
        admin_approved,
        cycle_number_at_purchase,
        created_at
      ) VALUES (
        v_user_record.user_id,
        p_date,
        1000,
        TRUE,
        TRUE,
        v_user_record.auto_nft_count + 1,
        NOW()
      );

      -- affiliate_cycleを更新
      UPDATE affiliate_cycle
      SET
        cum_usdt = cum_usdt - 1100,
        available_usdt = available_usdt + 1100,
        auto_nft_count = auto_nft_count + 1,
        phase = CASE
          WHEN (cum_usdt - 1100) >= 1100 THEN 'HOLD'
          ELSE 'USDT'
        END,
        updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_auto_nft_count := v_auto_nft_count + 1;
    END LOOP;

    v_total_stock := v_distribution_stock;
  END IF;

  -- ========================================
  -- STEP 12: 結果を返す
  -- ========================================
  RETURN QUERY SELECT
    'SUCCESS'::TEXT,
    format('日利配布完了: %s名に総額$%s配布、NFT自動付与: %s件',
      (SELECT COUNT(DISTINCT user_id) FROM user_daily_profit WHERE date = p_date),
      v_total_distributed::TEXT,
      v_auto_nft_count::TEXT
    )::TEXT,
    jsonb_build_object(
      'date', p_date,
      'total_nft_count', v_total_nft_count,
      'profit_per_nft', v_profit_per_nft,
      'daily_pnl', v_daily_pnl,
      'distributed', v_total_distributed,
      'referral', 0,  -- 紹介報酬は月末に計算
      'stock', v_total_stock,
      'auto_nft_count', v_auto_nft_count,
      'test_mode', p_is_test_mode
    );
END;
$$;

-- 関数作成完了メッセージ
DO $$
BEGIN
  RAISE NOTICE '=========================================';
  RAISE NOTICE '✅ V2日利処理関数作成完了（紹介報酬なし版）';
  RAISE NOTICE '=========================================';
  RAISE NOTICE '関数名: process_daily_yield_v2';
  RAISE NOTICE '変更内容:';
  RAISE NOTICE '  - 紹介報酬の計算を削除';
  RAISE NOTICE '  - 日利配布とNFT自動付与のみ実行';
  RAISE NOTICE '  - 紹介報酬は月末に process_monthly_referral_reward() で計算';
  RAISE NOTICE '=========================================';
END $$;
