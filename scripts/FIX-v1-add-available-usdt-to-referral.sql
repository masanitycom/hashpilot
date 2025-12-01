-- ========================================
-- V1関数を修正: 紹介報酬をavailable_usdtにも加算
-- ========================================

CREATE OR REPLACE FUNCTION process_daily_yield_with_cycles(
    p_date DATE,
    p_yield_rate NUMERIC,
    p_margin_rate NUMERIC,
    p_is_test_mode BOOLEAN DEFAULT FALSE,
    p_skip_validation BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(message TEXT, details JSONB)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_record RECORD;
  v_nft_record RECORD;
  v_personal_profit_per_nft NUMERIC;
  v_level1_rate NUMERIC := 0.20;
  v_level2_rate NUMERIC := 0.10;
  v_level3_rate NUMERIC := 0.05;
  v_user_profit NUMERIC;
  v_referral_user_id VARCHAR(10);
  v_level1_user_id VARCHAR(10);
  v_level2_user_id VARCHAR(10);
  v_cumulative_usdt NUMERIC;
  v_phase TEXT;
  v_total_users INTEGER := 0;
  v_total_personal_profit NUMERIC := 0;
  v_total_referral_profit NUMERIC := 0;
  v_total_auto_nft INTEGER := 0;
  v_nft_count INTEGER;
  v_child_nft_count INTEGER;
  v_user_rate NUMERIC;
  v_is_month_end BOOLEAN;
  v_year_month TEXT;
  v_monthly_result RECORD;
BEGIN
  IF NOT p_skip_validation THEN
    IF p_date > CURRENT_DATE THEN
      RAISE EXCEPTION '未来の日付には日利を設定できません';
    END IF;

    IF p_yield_rate < -0.1 OR p_yield_rate > 0.1 THEN
      RAISE EXCEPTION '日利率は-10%%から10%%の範囲で設定してください';
    END IF;

    IF p_margin_rate < 0 OR p_margin_rate > 1 THEN
      RAISE EXCEPTION 'マージン率は0%%から100%%の範囲で設定してください';
    END IF;
  END IF;

  v_personal_profit_per_nft := (1000.0 * p_yield_rate) * (1.0 - p_margin_rate) * 0.6;
  v_user_rate := p_yield_rate * (1.0 - p_margin_rate) * 0.6;
  v_is_month_end := (EXTRACT(DAY FROM (p_date + INTERVAL '1 day')) = 1);
  v_year_month := TO_CHAR(p_date, 'YYYY-MM');

  DELETE FROM nft_daily_profit WHERE date = p_date;

  FOR v_user_record IN
    SELECT
      u.user_id,
      u.exclude_from_daily_profit,
      u.operation_start_date
    FROM users u
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= p_date
  LOOP
    IF v_user_record.exclude_from_daily_profit = TRUE THEN
      CONTINUE;
    END IF;

    v_nft_count := 0;

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
        v_personal_profit_per_nft,
        'USDT',
        NOW()
      );
      v_nft_count := v_nft_count + 1;
    END LOOP;

    IF v_nft_count > 0 THEN
      UPDATE affiliate_cycle
      SET
        available_usdt = available_usdt + (v_personal_profit_per_nft * v_nft_count),
        updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_users := v_total_users + 1;
      v_total_personal_profit := v_total_personal_profit + (v_personal_profit_per_nft * v_nft_count);
    END IF;
  END LOOP;

  DELETE FROM user_referral_profit WHERE date = p_date;

  IF v_personal_profit_per_nft > 0 THEN
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
      v_user_profit := v_personal_profit_per_nft * v_child_nft_count;

      v_level1_user_id := v_user_record.referrer_user_id;

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

          -- ✅ 修正: available_usdtにも加算
          UPDATE affiliate_cycle
          SET
            cum_usdt = cum_usdt + (v_user_profit * v_level1_rate),
            available_usdt = available_usdt + (v_user_profit * v_level1_rate),
            updated_at = NOW()
          WHERE user_id = v_level1_user_id;

          v_total_referral_profit := v_total_referral_profit + (v_user_profit * v_level1_rate);
        END IF;

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

            -- ✅ 修正: available_usdtにも加算
            UPDATE affiliate_cycle
            SET
              cum_usdt = cum_usdt + (v_user_profit * v_level2_rate),
              available_usdt = available_usdt + (v_user_profit * v_level2_rate),
              updated_at = NOW()
            WHERE user_id = v_level2_user_id;

            v_total_referral_profit := v_total_referral_profit + (v_user_profit * v_level2_rate);
          END IF;

          SELECT referrer_user_id INTO v_referral_user_id
          FROM users
          WHERE user_id = v_level2_user_id;

          IF v_referral_user_id IS NOT NULL THEN
            IF EXISTS (
              SELECT 1 FROM users
              WHERE user_id = v_referral_user_id
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
                v_referral_user_id,
                p_date,
                3,
                v_user_record.user_id,
                v_user_profit * v_level3_rate,
                NOW()
              );

              -- ✅ 修正: available_usdtにも加算
              UPDATE affiliate_cycle
              SET
                cum_usdt = cum_usdt + (v_user_profit * v_level3_rate),
                available_usdt = available_usdt + (v_user_profit * v_level3_rate),
                updated_at = NOW()
              WHERE user_id = v_referral_user_id;

              v_total_referral_profit := v_total_referral_profit + (v_user_profit * v_level3_rate);
            END IF;
          END IF;
        END IF;
      END IF;
    END LOOP;
  END IF;

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

    v_total_auto_nft := v_total_auto_nft + 1;
  END LOOP;

  DELETE FROM daily_yield_log WHERE date = p_date;

  INSERT INTO daily_yield_log (
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
  ) VALUES (
    p_date,
    p_yield_rate * 100,
    p_margin_rate,
    v_user_rate * 100,
    v_is_month_end,
    NOW()
  );

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

  RETURN QUERY SELECT
    '日利処理が完了しました'::TEXT as message,
    jsonb_build_object(
      'date', p_date,
      'yield_rate', p_yield_rate,
      'margin_rate', p_margin_rate,
      'personal_profit_per_nft', v_personal_profit_per_nft,
      'total_users', v_total_users,
      'total_personal_profit', v_total_personal_profit,
      'total_referral_profit', v_total_referral_profit,
      'total_auto_nft', v_total_auto_nft,
      'is_month_end', v_is_month_end,
      'is_test_mode', p_is_test_mode
    ) as details;
END;
$$;

-- ========================================
-- 完了メッセージ
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ V1関数を修正しました';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '修正内容:';
    RAISE NOTICE '  - Level 1紹介報酬: cum_usdt + available_usdt に加算';
    RAISE NOTICE '  - Level 2紹介報酬: cum_usdt + available_usdt に加算';
    RAISE NOTICE '  - Level 3紹介報酬: cum_usdt + available_usdt に加算';
    RAISE NOTICE '';
    RAISE NOTICE '次のステップ:';
    RAISE NOTICE '  11月の紹介報酬をavailable_usdtに反映するスクリプトを実行';
    RAISE NOTICE '===========================================';
END $$;
