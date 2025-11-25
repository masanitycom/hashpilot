-- ========================================
-- V2関数のnft_sequence衝突を修正
-- ========================================
-- 問題: auto_nft_count + 1 が手動NFTのシーケンスと衝突
-- 解決: ユーザーの最大シーケンス + 1 を使用
-- ========================================

DROP FUNCTION IF EXISTS process_daily_yield_v2(DATE, NUMERIC, BOOLEAN);

CREATE FUNCTION process_daily_yield_v2(
  p_date DATE,
  p_total_profit_amount NUMERIC,
  p_is_test_mode BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
AS $function$
DECLARE
  v_user_record RECORD;
  v_nft_record RECORD;
  v_total_nft_count INTEGER := 0;
  v_distribution_dividend NUMERIC;
  v_personal_profit_per_nft NUMERIC;
  v_level1_rate NUMERIC := 0.20;
  v_level2_rate NUMERIC := 0.10;
  v_level3_rate NUMERIC := 0.05;
  v_user_profit NUMERIC;
  v_referral_user_id VARCHAR(10);
  v_level1_user_id VARCHAR(10);
  v_level2_user_id VARCHAR(10);
  v_total_users INTEGER := 0;
  v_total_personal_profit NUMERIC := 0;
  v_total_referral_profit NUMERIC := 0;
  v_total_auto_nft INTEGER := 0;
  v_nft_count INTEGER;
  v_child_nft_count INTEGER;
  v_prev_gross_profit NUMERIC := 0;
  v_prev_fee NUMERIC := 0;
  v_prev_net_profit NUMERIC := 0;
  v_cumulative_gross_profit NUMERIC;
  v_cumulative_fee NUMERIC;
  v_cumulative_net_profit NUMERIC;
  v_daily_pnl NUMERIC;
  v_max_sequence INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_total_nft_count FROM nft_master WHERE buyback_date IS NULL;

  IF v_total_nft_count = 0 THEN
    RAISE EXCEPTION '有効なNFTが存在しません';
  END IF;

  v_distribution_dividend := p_total_profit_amount * 0.6;
  v_personal_profit_per_nft := v_distribution_dividend / v_total_nft_count;

  SELECT
    COALESCE(cumulative_gross_profit, 0),
    COALESCE(cumulative_fee, 0),
    COALESCE(cumulative_net_profit, 0)
  INTO v_prev_gross_profit, v_prev_fee, v_prev_net_profit
  FROM daily_yield_log_v2
  WHERE date < p_date
  ORDER BY date DESC
  LIMIT 1;

  v_cumulative_gross_profit := v_prev_gross_profit + p_total_profit_amount;
  v_cumulative_fee := v_prev_fee + (p_total_profit_amount * 0.30);
  v_cumulative_net_profit := v_prev_net_profit + (p_total_profit_amount * 0.70);
  v_daily_pnl := p_total_profit_amount * 0.70;

  DELETE FROM nft_daily_profit WHERE date = p_date;

  FOR v_user_record IN
    SELECT u.user_id, u.is_pegasus_exchange, u.operation_start_date
    FROM users u
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= p_date
  LOOP
    IF v_user_record.is_pegasus_exchange = TRUE THEN
      CONTINUE;
    END IF;

    v_nft_count := 0;

    FOR v_nft_record IN
      SELECT id FROM nft_master
      WHERE user_id = v_user_record.user_id AND buyback_date IS NULL
    LOOP
      INSERT INTO nft_daily_profit (nft_id, user_id, date, daily_profit, phase, created_at)
      VALUES (v_nft_record.id, v_user_record.user_id, p_date, v_personal_profit_per_nft, 'USDT', NOW());
      v_nft_count := v_nft_count + 1;
    END LOOP;

    IF v_nft_count > 0 THEN
      UPDATE affiliate_cycle
      SET available_usdt = available_usdt + (v_personal_profit_per_nft * v_nft_count), updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_users := v_total_users + 1;
      v_total_personal_profit := v_total_personal_profit + (v_personal_profit_per_nft * v_nft_count);
    END IF;
  END LOOP;

  DELETE FROM user_referral_profit WHERE date = p_date;

  IF v_personal_profit_per_nft > 0 THEN
    FOR v_user_record IN
      SELECT u.user_id, u.referrer_user_id, u.operation_start_date, COUNT(nm.id) as nft_count
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
      v_user_profit := v_personal_profit_per_nft * v_child_nft_count;
      v_level1_user_id := v_user_record.referrer_user_id;

      IF v_level1_user_id IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM users WHERE user_id = v_level1_user_id AND operation_start_date IS NOT NULL AND operation_start_date <= p_date) THEN
          INSERT INTO user_referral_profit (user_id, date, referral_level, child_user_id, profit_amount, created_at)
          VALUES (v_level1_user_id, p_date, 1, v_user_record.user_id, v_user_profit * v_level1_rate, NOW());

          UPDATE affiliate_cycle SET cum_usdt = cum_usdt + (v_user_profit * v_level1_rate), updated_at = NOW()
          WHERE user_id = v_level1_user_id;

          v_total_referral_profit := v_total_referral_profit + (v_user_profit * v_level1_rate);
        END IF;

        SELECT referrer_user_id INTO v_level2_user_id FROM users WHERE user_id = v_level1_user_id;

        IF v_level2_user_id IS NOT NULL THEN
          IF EXISTS (SELECT 1 FROM users WHERE user_id = v_level2_user_id AND operation_start_date IS NOT NULL AND operation_start_date <= p_date) THEN
            INSERT INTO user_referral_profit (user_id, date, referral_level, child_user_id, profit_amount, created_at)
            VALUES (v_level2_user_id, p_date, 2, v_user_record.user_id, v_user_profit * v_level2_rate, NOW());

            UPDATE affiliate_cycle SET cum_usdt = cum_usdt + (v_user_profit * v_level2_rate), updated_at = NOW()
            WHERE user_id = v_level2_user_id;

            v_total_referral_profit := v_total_referral_profit + (v_user_profit * v_level2_rate);
          END IF;

          SELECT referrer_user_id INTO v_referral_user_id FROM users WHERE user_id = v_level2_user_id;

          IF v_referral_user_id IS NOT NULL THEN
            IF EXISTS (SELECT 1 FROM users WHERE user_id = v_referral_user_id AND operation_start_date IS NOT NULL AND operation_start_date <= p_date) THEN
              INSERT INTO user_referral_profit (user_id, date, referral_level, child_user_id, profit_amount, created_at)
              VALUES (v_referral_user_id, p_date, 3, v_user_record.user_id, v_user_profit * v_level3_rate, NOW());

              UPDATE affiliate_cycle SET cum_usdt = cum_usdt + (v_user_profit * v_level3_rate), updated_at = NOW()
              WHERE user_id = v_referral_user_id;

              v_total_referral_profit := v_total_referral_profit + (v_user_profit * v_level3_rate);
            END IF;
          END IF;
        END IF;
      END IF;
    END LOOP;
  END IF;

  -- ★ 修正: 最大シーケンス番号を取得して使用
  FOR v_user_record IN
    SELECT ac.user_id, ac.cum_usdt, ac.phase, COALESCE(ac.auto_nft_count, 0) as auto_nft_count
    FROM affiliate_cycle ac
    WHERE ac.cum_usdt >= 2200
      AND EXISTS (SELECT 1 FROM users WHERE users.user_id = ac.user_id AND operation_start_date IS NOT NULL AND operation_start_date <= p_date)
  LOOP
    -- ★ そのユーザーの最大シーケンス番号を取得
    SELECT COALESCE(MAX(nft_sequence), 0) INTO v_max_sequence
    FROM nft_master
    WHERE user_id = v_user_record.user_id;

    INSERT INTO nft_master (user_id, nft_type, nft_sequence, nft_value, acquired_date, created_at)
    VALUES (v_user_record.user_id, 'auto', v_max_sequence + 1, 1000, p_date, NOW());

    INSERT INTO purchases (user_id, amount_usd, admin_approved, is_auto_purchase, created_at)
    VALUES (v_user_record.user_id, 1100, TRUE, TRUE, NOW());

    UPDATE affiliate_cycle
    SET
      cum_usdt = cum_usdt - 2200,
      available_usdt = available_usdt + 1100,
      auto_nft_count = COALESCE(auto_nft_count, 0) + 1,
      total_nft_count = total_nft_count + 1,
      phase = CASE WHEN (cum_usdt - 2200) >= 1100 THEN 'HOLD' ELSE 'USDT' END,
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id;

    v_total_auto_nft := v_total_auto_nft + 1;
  END LOOP;

  INSERT INTO daily_yield_log_v2 (
    date, total_profit_amount, total_nft_count, profit_per_nft,
    cumulative_gross_profit, fee_rate, cumulative_fee, cumulative_net_profit, daily_pnl,
    distribution_dividend, distribution_affiliate, distribution_stock, is_month_end, created_at
  ) VALUES (
    p_date, p_total_profit_amount, v_total_nft_count, v_personal_profit_per_nft,
    v_cumulative_gross_profit, 0.30, v_cumulative_fee, v_cumulative_net_profit, v_daily_pnl,
    v_distribution_dividend, p_total_profit_amount * 0.30, p_total_profit_amount * 0.10,
    (EXTRACT(DAY FROM (p_date + INTERVAL '1 day')) = 1), NOW()
  )
  ON CONFLICT (date) DO UPDATE SET
    total_profit_amount = EXCLUDED.total_profit_amount,
    total_nft_count = EXCLUDED.total_nft_count,
    profit_per_nft = EXCLUDED.profit_per_nft,
    cumulative_gross_profit = EXCLUDED.cumulative_gross_profit,
    cumulative_fee = EXCLUDED.cumulative_fee,
    cumulative_net_profit = EXCLUDED.cumulative_net_profit,
    daily_pnl = EXCLUDED.daily_pnl,
    distribution_dividend = EXCLUDED.distribution_dividend,
    distribution_affiliate = EXCLUDED.distribution_affiliate,
    distribution_stock = EXCLUDED.distribution_stock,
    is_month_end = EXCLUDED.is_month_end;

  RETURN jsonb_build_object(
    'status', 'SUCCESS',
    'message', '日利計算完了: ' || p_date,
    'details', jsonb_build_object(
      'date', p_date,
      'total_profit_amount', p_total_profit_amount,
      'total_nft_count', v_total_nft_count,
      'profit_per_nft', v_personal_profit_per_nft,
      'distribution_dividend', v_distribution_dividend,
      'total_users', v_total_users,
      'total_personal_profit', v_total_personal_profit,
      'total_referral_profit', v_total_referral_profit,
      'total_auto_nft', v_total_auto_nft,
      'is_test_mode', p_is_test_mode
    )
  );
END;
$function$;

SELECT '✅ V2関数のnft_sequence衝突を修正しました（最大シーケンス+1を使用）' as status;
