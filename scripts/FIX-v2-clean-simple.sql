-- ========================================
-- V2関数の修正（シンプル版）
-- ========================================

-- 1. 既存の全関数を削除
DROP FUNCTION IF EXISTS process_daily_yield_v2(DATE, NUMERIC, BOOLEAN);
DROP FUNCTION IF EXISTS process_daily_yield_v2(DATE, NUMERIC, BOOLEAN, BOOLEAN);

-- 2. 正しい関数を作成
CREATE FUNCTION process_daily_yield_v2(
  p_date DATE,
  p_total_profit_amount NUMERIC,
  p_is_test_mode BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
AS $function$
DECLARE
  v_distribution_dividend NUMERIC := p_total_profit_amount * 0.6;
  v_level1_rate NUMERIC := 0.20;
  v_level2_rate NUMERIC := 0.10;
  v_level3_rate NUMERIC := 0.05;
  v_user_record RECORD;
  v_referral_record RECORD;
  v_total_personal NUMERIC := 0;
  v_total_referral NUMERIC := 0;
  v_personal_count INTEGER := 0;
  v_referral_count INTEGER := 0;
  v_auto_nft_count INTEGER := 0;
  v_cycle_update_count INTEGER := 0;
  v_total_nft_count INTEGER := 0;
  v_user_profit NUMERIC;
  v_per_nft_profit NUMERIC;
  v_margin_rate NUMERIC;
  v_yield_rate NUMERIC;
  v_user_rate NUMERIC;
BEGIN
  SELECT COUNT(*) INTO v_total_nft_count FROM nft_master WHERE buyback_date IS NULL;

  IF v_total_nft_count = 0 THEN
    RETURN jsonb_build_object(
      'status', 'ERROR',
      'message', '有効なNFTが存在しません',
      'details', jsonb_build_object('total_nft_count', 0)
    );
  END IF;

  v_per_nft_profit := v_distribution_dividend / v_total_nft_count;
  v_yield_rate := (p_total_profit_amount / (v_total_nft_count * 1000)) * 100;
  v_margin_rate := 30.0;
  v_user_rate := v_yield_rate * 0.7 * 0.6;

  INSERT INTO daily_yield_log_v2 (
    date, total_profit_amount, distribution_dividend, total_nft_count,
    per_nft_profit, yield_rate, margin_rate, user_rate, is_test_mode
  ) VALUES (
    p_date, p_total_profit_amount, v_distribution_dividend, v_total_nft_count,
    v_per_nft_profit, v_yield_rate, v_margin_rate, v_user_rate, p_is_test_mode
  )
  ON CONFLICT (date) DO UPDATE SET
    total_profit_amount = EXCLUDED.total_profit_amount,
    distribution_dividend = EXCLUDED.distribution_dividend,
    total_nft_count = EXCLUDED.total_nft_count,
    per_nft_profit = EXCLUDED.per_nft_profit,
    yield_rate = EXCLUDED.yield_rate,
    margin_rate = EXCLUDED.margin_rate,
    user_rate = EXCLUDED.user_rate,
    is_test_mode = EXCLUDED.is_test_mode,
    updated_at = NOW();

  FOR v_user_record IN
    SELECT u.user_id, COALESCE(SUM(CASE WHEN nm.buyback_date IS NULL THEN 1 ELSE 0 END), 0) as active_nft_count
    FROM users u
    LEFT JOIN nft_master nm ON u.user_id = nm.user_id
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= p_date
    GROUP BY u.user_id
    HAVING COALESCE(SUM(CASE WHEN nm.buyback_date IS NULL THEN 1 ELSE 0 END), 0) > 0
  LOOP
    v_user_profit := v_per_nft_profit * v_user_record.active_nft_count;

    INSERT INTO nft_daily_profit (user_id, date, daily_profit)
    VALUES (v_user_record.user_id, p_date, v_user_profit)
    ON CONFLICT (user_id, date) DO UPDATE SET daily_profit = EXCLUDED.daily_profit, updated_at = NOW();

    UPDATE affiliate_cycle SET available_usdt = available_usdt + v_user_profit, updated_at = NOW()
    WHERE user_id = v_user_record.user_id;

    v_total_personal := v_total_personal + v_user_profit;
    v_personal_count := v_personal_count + 1;
  END LOOP;

  IF v_distribution_dividend > 0 THEN
    FOR v_user_record IN
      SELECT DISTINCT u.user_id FROM users u
      WHERE u.has_approved_nft = true AND u.operation_start_date IS NOT NULL AND u.operation_start_date <= p_date
        AND EXISTS (SELECT 1 FROM users child WHERE child.referrer_user_id = u.user_id)
    LOOP
      FOR v_referral_record IN
        SELECT child.user_id as child_user_id, COALESCE(SUM(ndp.daily_profit), 0) as child_profit
        FROM users child
        LEFT JOIN nft_daily_profit ndp ON ndp.user_id = child.user_id AND ndp.date = p_date
        WHERE child.referrer_user_id = v_user_record.user_id
          AND child.has_approved_nft = true AND child.operation_start_date IS NOT NULL AND child.operation_start_date <= p_date
        GROUP BY child.user_id
        HAVING COALESCE(SUM(ndp.daily_profit), 0) > 0
      LOOP
        INSERT INTO user_referral_profit (user_id, date, referral_level, child_user_id, profit_amount)
        VALUES (v_user_record.user_id, p_date, 1, v_referral_record.child_user_id, v_referral_record.child_profit * v_level1_rate);

        UPDATE affiliate_cycle SET
          cum_usdt = cum_usdt + (v_referral_record.child_profit * v_level1_rate),
          available_usdt = available_usdt + (v_referral_record.child_profit * v_level1_rate),
          updated_at = NOW()
        WHERE user_id = v_user_record.user_id;

        v_total_referral := v_total_referral + (v_referral_record.child_profit * v_level1_rate);
        v_referral_count := v_referral_count + 1;
      END LOOP;
    END LOOP;
  END IF;

  IF v_distribution_dividend > 0 THEN
    FOR v_user_record IN
      SELECT DISTINCT u.user_id FROM users u
      WHERE u.has_approved_nft = true AND u.operation_start_date IS NOT NULL AND u.operation_start_date <= p_date
        AND EXISTS (SELECT 1 FROM users child JOIN users grandchild ON grandchild.referrer_user_id = child.user_id WHERE child.referrer_user_id = u.user_id)
    LOOP
      FOR v_referral_record IN
        SELECT grandchild.user_id as child_user_id, COALESCE(SUM(ndp.daily_profit), 0) as child_profit
        FROM users child
        JOIN users grandchild ON grandchild.referrer_user_id = child.user_id
        LEFT JOIN nft_daily_profit ndp ON ndp.user_id = grandchild.user_id AND ndp.date = p_date
        WHERE child.referrer_user_id = v_user_record.user_id
          AND grandchild.has_approved_nft = true AND grandchild.operation_start_date IS NOT NULL AND grandchild.operation_start_date <= p_date
        GROUP BY grandchild.user_id
        HAVING COALESCE(SUM(ndp.daily_profit), 0) > 0
      LOOP
        INSERT INTO user_referral_profit (user_id, date, referral_level, child_user_id, profit_amount)
        VALUES (v_user_record.user_id, p_date, 2, v_referral_record.child_user_id, v_referral_record.child_profit * v_level2_rate);

        UPDATE affiliate_cycle SET
          cum_usdt = cum_usdt + (v_referral_record.child_profit * v_level2_rate),
          available_usdt = available_usdt + (v_referral_record.child_profit * v_level2_rate),
          updated_at = NOW()
        WHERE user_id = v_user_record.user_id;

        v_total_referral := v_total_referral + (v_referral_record.child_profit * v_level2_rate);
        v_referral_count := v_referral_count + 1;
      END LOOP;
    END LOOP;
  END IF;

  IF v_distribution_dividend > 0 THEN
    FOR v_user_record IN
      SELECT DISTINCT u.user_id FROM users u
      WHERE u.has_approved_nft = true AND u.operation_start_date IS NOT NULL AND u.operation_start_date <= p_date
        AND EXISTS (SELECT 1 FROM users child JOIN users grandchild ON grandchild.referrer_user_id = child.user_id JOIN users great_grandchild ON great_grandchild.referrer_user_id = grandchild.user_id WHERE child.referrer_user_id = u.user_id)
    LOOP
      FOR v_referral_record IN
        SELECT great_grandchild.user_id as child_user_id, COALESCE(SUM(ndp.daily_profit), 0) as child_profit
        FROM users child
        JOIN users grandchild ON grandchild.referrer_user_id = child.user_id
        JOIN users great_grandchild ON great_grandchild.referrer_user_id = grandchild.user_id
        LEFT JOIN nft_daily_profit ndp ON ndp.user_id = great_grandchild.user_id AND ndp.date = p_date
        WHERE child.referrer_user_id = v_user_record.user_id
          AND great_grandchild.has_approved_nft = true AND great_grandchild.operation_start_date IS NOT NULL AND great_grandchild.operation_start_date <= p_date
        GROUP BY great_grandchild.user_id
        HAVING COALESCE(SUM(ndp.daily_profit), 0) > 0
      LOOP
        INSERT INTO user_referral_profit (user_id, date, referral_level, child_user_id, profit_amount)
        VALUES (v_user_record.user_id, p_date, 3, v_referral_record.child_user_id, v_referral_record.child_profit * v_level3_rate);

        UPDATE affiliate_cycle SET
          cum_usdt = cum_usdt + (v_referral_record.child_profit * v_level3_rate),
          available_usdt = available_usdt + (v_referral_record.child_profit * v_level3_rate),
          updated_at = NOW()
        WHERE user_id = v_user_record.user_id;

        v_total_referral := v_total_referral + (v_referral_record.child_profit * v_level3_rate);
        v_referral_count := v_referral_count + 1;
      END LOOP;
    END LOOP;
  END IF;

  FOR v_user_record IN
    SELECT u.user_id, u.id as user_uuid, ac.cum_usdt, COALESCE(ac.auto_nft_count, 0) as auto_nft_count
    FROM users u
    JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE ac.cum_usdt >= 2200
  LOOP
    INSERT INTO nft_master (user_id, nft_type, nft_sequence, nft_value, acquired_date, buyback_date)
    VALUES (v_user_record.user_id, 'auto', v_user_record.auto_nft_count + 1, 1000, p_date, NULL);

    INSERT INTO purchases (user_id, nft_type, usdt_amount, payment_tx_id, payment_method, admin_approved, admin_approved_at, cycle_number_at_purchase, purchase_date)
    VALUES (v_user_record.user_id, 'auto', 1100, 'AUTO_' || p_date || '_' || v_user_record.user_id, 'cycle_reward', true, NOW(), v_user_record.auto_nft_count + 1, p_date);

    UPDATE affiliate_cycle SET
      cum_usdt = cum_usdt - 1100,
      available_usdt = available_usdt + 1100,
      auto_nft_count = COALESCE(auto_nft_count, 0) + 1,
      total_nft_count = total_nft_count + 1,
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id;

    v_auto_nft_count := v_auto_nft_count + 1;
    v_cycle_update_count := v_cycle_update_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'status', 'SUCCESS',
    'message', '日利計算完了: ' || p_date,
    'details', jsonb_build_object(
      'date', p_date,
      'total_profit_amount', p_total_profit_amount,
      'distribution_dividend', v_distribution_dividend,
      'total_nft_count', v_total_nft_count,
      'per_nft_profit', v_per_nft_profit,
      'yield_rate', v_yield_rate,
      'user_rate', v_user_rate,
      'personal_distribution', jsonb_build_object('count', v_personal_count, 'amount', v_total_personal),
      'referral_distribution', jsonb_build_object('count', v_referral_count, 'amount', v_total_referral),
      'auto_nft_grants', v_auto_nft_count,
      'cycle_updates', v_cycle_update_count,
      'is_test_mode', p_is_test_mode
    )
  );
END;
$function$;
