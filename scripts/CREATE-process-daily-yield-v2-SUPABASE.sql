-- ========================================
-- V2日利処理関数（完全版・Supabase対応）
-- 入力: 金額（$）
-- 機能: V1と完全同等（月末処理、NFTサイクル、Level1-3紹介報酬）
-- ========================================
-- 作成日: 2025-11-30
-- 目的: V1からV2への完全移行準備

CREATE OR REPLACE FUNCTION public.process_daily_yield_v2(
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
AS $function$
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
  v_total_referral NUMERIC := 0;
  v_referral_count INTEGER := 0;
  v_auto_nft_count INTEGER := 0;
  v_level1_rate NUMERIC := 0.20;
  v_level2_rate NUMERIC := 0.10;
  v_level3_rate NUMERIC := 0.05;
  v_level1_user_id VARCHAR(10);
  v_level2_user_id VARCHAR(10);
  v_level3_user_id VARCHAR(10);
  v_child_nft_count INTEGER;
  v_is_month_end BOOLEAN;
  v_year_month TEXT;
  v_monthly_result RECORD;
BEGIN
  -- 入力検証
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
      DELETE FROM daily_yield_log_v2 WHERE date = p_date;
      DELETE FROM nft_daily_profit WHERE date = p_date;
      DELETE FROM user_referral_profit WHERE date = p_date;
    END IF;
  END IF;

  -- 月末判定
  v_is_month_end := (EXTRACT(DAY FROM (p_date + INTERVAL '1 day')) = 1);
  v_year_month := TO_CHAR(p_date, 'YYYY-MM');

  -- STEP 1: NFT総数を取得
  SELECT COUNT(*)
  INTO v_total_nft_count
  FROM nft_master nm
  JOIN users u ON nm.user_id = u.user_id
  WHERE nm.buyback_date IS NULL
    AND u.operation_start_date IS NOT NULL
    AND u.operation_start_date <= p_date
    AND (u.exclude_from_daily_profit = FALSE OR u.exclude_from_daily_profit IS NULL);

  IF v_total_nft_count = 0 THEN
    RETURN QUERY SELECT 'ERROR'::TEXT, '運用中のNFTが見つかりません'::TEXT, NULL::JSONB;
    RETURN;
  END IF;

  v_profit_per_nft := p_total_profit_amount / v_total_nft_count;

  -- STEP 2: 累積利益計算
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
  v_cumulative_gross := v_prev_cumulative_gross + p_total_profit_amount;
  v_cumulative_fee := v_fee_rate * GREATEST(v_cumulative_gross, 0);
  v_cumulative_net := v_cumulative_gross - v_cumulative_fee;
  v_daily_pnl := v_cumulative_net - v_prev_cumulative_net;

  -- STEP 3: 配分計算（プラス・マイナス共通）
  v_distribution_dividend := v_daily_pnl * 0.60;
  v_distribution_affiliate := v_daily_pnl * 0.30;
  v_distribution_stock := v_daily_pnl * 0.10;

  -- STEP 4: 個人利益配布（60%）
  IF v_distribution_dividend != 0 THEN
    FOR v_user_record IN
      SELECT
        u.user_id,
        COUNT(nm.id) as nft_count
      FROM users u
      JOIN nft_master nm ON u.user_id = nm.user_id
      WHERE nm.buyback_date IS NULL
        AND u.operation_start_date IS NOT NULL
        AND u.operation_start_date <= p_date
        AND (u.exclude_from_daily_profit = FALSE OR u.exclude_from_daily_profit IS NULL)
      GROUP BY u.user_id
    LOOP
      v_user_nft_count := v_user_record.nft_count;
      v_user_profit := (v_distribution_dividend / v_total_nft_count) * v_user_nft_count;

      FOR v_nft_record IN
        SELECT id FROM nft_master
        WHERE user_id = v_user_record.user_id AND buyback_date IS NULL
      LOOP
        INSERT INTO nft_daily_profit (
          nft_id,
          user_id,
          date,
          daily_profit,
          phase,
          created_at
        ) VALUES (
          v_nft_record.id,
          v_user_record.user_id,
          p_date,
          v_profit_per_nft * 0.60,
          'USDT',
          NOW()
        );
      END LOOP;

      UPDATE affiliate_cycle
      SET
        available_usdt = available_usdt + v_user_profit,
        updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_distributed := v_total_distributed + v_user_profit;
    END LOOP;
  END IF;

  -- STEP 5: 紹介報酬配布（30%、プラスの時のみ）
  IF v_distribution_affiliate > 0 THEN
    FOR v_user_record IN
      SELECT
        u.user_id,
        u.referrer_user_id,
        u.operation_start_date,
        COUNT(nm.id) as nft_count
      FROM users u
      INNER JOIN nft_master nm ON u.user_id = nm.user_id
      WHERE nm.buyback_date IS NULL
        AND u.has_approved_nft = true
        AND u.operation_start_date IS NOT NULL
        AND u.operation_start_date <= p_date
        AND u.referrer_user_id IS NOT NULL
      GROUP BY u.user_id, u.referrer_user_id, u.operation_start_date
    LOOP
      v_child_nft_count := v_user_record.nft_count;
      v_user_profit := v_profit_per_nft * 0.60 * v_child_nft_count;
      v_level1_user_id := v_user_record.referrer_user_id;

      -- Level 1紹介報酬
      IF v_level1_user_id IS NOT NULL THEN
        IF EXISTS (
          SELECT 1 FROM users
          WHERE user_id = v_level1_user_id
            AND operation_start_date IS NOT NULL
            AND operation_start_date <= p_date
        ) THEN
          INSERT INTO user_referral_profit (
            user_id,
            date,
            referral_level,
            child_user_id,
            profit_amount,
            created_at
          ) VALUES (
            v_level1_user_id,
            p_date,
            1,
            v_user_record.user_id,
            v_user_profit * v_level1_rate,
            NOW()
          );

          UPDATE affiliate_cycle
          SET
            cum_usdt = cum_usdt + (v_user_profit * v_level1_rate),
            available_usdt = available_usdt + (v_user_profit * v_level1_rate),
            updated_at = NOW()
          WHERE user_id = v_level1_user_id;

          v_total_referral := v_total_referral + (v_user_profit * v_level1_rate);
          v_referral_count := v_referral_count + 1;
        END IF;

        -- Level 2紹介報酬
        SELECT referrer_user_id INTO v_level2_user_id
        FROM users
        WHERE user_id = v_level1_user_id;

        IF v_level2_user_id IS NOT NULL THEN
          IF EXISTS (
            SELECT 1 FROM users
            WHERE user_id = v_level2_user_id
              AND operation_start_date IS NOT NULL
              AND operation_start_date <= p_date
          ) THEN
            INSERT INTO user_referral_profit (
              user_id,
              date,
              referral_level,
              child_user_id,
              profit_amount,
              created_at
            ) VALUES (
              v_level2_user_id,
              p_date,
              2,
              v_user_record.user_id,
              v_user_profit * v_level2_rate,
              NOW()
            );

            UPDATE affiliate_cycle
            SET
              cum_usdt = cum_usdt + (v_user_profit * v_level2_rate),
              available_usdt = available_usdt + (v_user_profit * v_level2_rate),
              updated_at = NOW()
            WHERE user_id = v_level2_user_id;

            v_total_referral := v_total_referral + (v_user_profit * v_level2_rate);
            v_referral_count := v_referral_count + 1;
          END IF;

          -- Level 3紹介報酬
          SELECT referrer_user_id INTO v_level3_user_id
          FROM users
          WHERE user_id = v_level2_user_id;

          IF v_level3_user_id IS NOT NULL THEN
            IF EXISTS (
              SELECT 1 FROM users
              WHERE user_id = v_level3_user_id
                AND operation_start_date IS NOT NULL
                AND operation_start_date <= p_date
            ) THEN
              INSERT INTO user_referral_profit (
                user_id,
                date,
                referral_level,
                child_user_id,
                profit_amount,
                created_at
              ) VALUES (
                v_level3_user_id,
                p_date,
                3,
                v_user_record.user_id,
                v_user_profit * v_level3_rate,
                NOW()
              );

              UPDATE affiliate_cycle
              SET
                cum_usdt = cum_usdt + (v_user_profit * v_level3_rate),
                available_usdt = available_usdt + (v_user_profit * v_level3_rate),
                updated_at = NOW()
              WHERE user_id = v_level3_user_id;

              v_total_referral := v_total_referral + (v_user_profit * v_level3_rate);
              v_referral_count := v_referral_count + 1;
            END IF;
          END IF;
        END IF;
      END IF;
    END LOOP;
  END IF;

  -- STEP 6: NFT自動付与
  FOR v_user_record IN
    SELECT
      user_id,
      cum_usdt,
      phase
    FROM affiliate_cycle
    WHERE cum_usdt >= 2200
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.user_id = affiliate_cycle.user_id
          AND operation_start_date IS NOT NULL
          AND operation_start_date <= p_date
      )
  LOOP
    INSERT INTO nft_master (
      user_id,
      nft_type,
      acquired_date,
      created_at
    ) VALUES (
      v_user_record.user_id,
      'auto',
      p_date,
      NOW()
    );

    INSERT INTO purchases (
      user_id,
      amount_usd,
      admin_approved,
      is_auto_purchase,
      created_at
    ) VALUES (
      v_user_record.user_id,
      1100,
      TRUE,
      TRUE,
      NOW()
    );

    UPDATE affiliate_cycle
    SET
      cum_usdt = cum_usdt - 2200,
      available_usdt = available_usdt + 1100,
      auto_nft_count = auto_nft_count + 1,
      total_nft_count = total_nft_count + 1,
      phase = CASE WHEN (cum_usdt - 2200) >= 1100 THEN 'HOLD' ELSE 'USDT' END,
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id;

    v_auto_nft_count := v_auto_nft_count + 1;
  END LOOP;

  -- STEP 7: ログ記録
  INSERT INTO daily_yield_log_v2 (
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
    created_at
  ) VALUES (
    p_date,
    p_total_profit_amount,
    v_total_nft_count,
    v_profit_per_nft,
    v_cumulative_gross,
    v_cumulative_fee,
    v_cumulative_net,
    v_daily_pnl,
    v_distribution_dividend,
    v_distribution_affiliate,
    v_distribution_stock,
    v_is_month_end,
    NOW()
  );

  -- STEP 8: 月末処理
  IF v_is_month_end THEN
    BEGIN
      SELECT * INTO v_monthly_result
      FROM process_monthly_referral_profit(v_year_month, false);
      RAISE NOTICE '月次紹介報酬計算完了: %', v_year_month;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING '月次紹介報酬計算でエラー: %', SQLERRM;
    END;

    BEGIN
      PERFORM process_monthly_withdrawals(p_date);
      RAISE NOTICE '月末自動出金処理完了: %', p_date;
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING '月末自動出金処理でエラー: %', SQLERRM;
    END;
  END IF;

  -- STEP 9: 結果を返す
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
        'gross', v_cumulative_gross,
        'fee', v_cumulative_fee,
        'net', v_cumulative_net,
        'daily_pnl', v_daily_pnl
      ),
      'distribution', jsonb_build_object(
        'dividend', v_distribution_dividend,
        'affiliate', v_distribution_affiliate,
        'stock', v_distribution_stock,
        'total_distributed', v_total_distributed,
        'total_referral', v_total_referral,
        'referral_count', v_referral_count,
        'auto_nft_count', v_auto_nft_count
      ),
      'is_month_end', v_is_month_end,
      'is_test_mode', p_is_test_mode
    );

EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT
      'ERROR'::TEXT,
      format('エラー: %s', SQLERRM)::TEXT,
      jsonb_build_object('error_detail', SQLERRM);
END;
$function$;

GRANT EXECUTE ON FUNCTION process_daily_yield_v2(DATE, NUMERIC, BOOLEAN) TO authenticated;
COMMENT ON FUNCTION process_daily_yield_v2 IS 'V2日利処理（金額入力、月末処理統合、Level1-3紹介報酬、NFTサイクル完全版）';
