-- ========================================
-- process_monthly_referral_reward関数のWHERE句追加修正
-- ========================================
-- 問題: STEP 6のUPDATE文にWHERE句がないためエラー発生
-- 修正: WHERE cum_usdt >= 0 を追加

CREATE OR REPLACE FUNCTION public.process_monthly_referral_reward(p_year integer, p_month integer, p_overwrite boolean DEFAULT false)
 RETURNS TABLE(status text, message text, details jsonb)
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_start_date DATE;
  v_end_date DATE;
  v_user_record RECORD;
  v_child_record RECORD;
  v_total_referral NUMERIC := 0;
  v_total_users INTEGER := 0;
  v_total_records INTEGER := 0;
  v_auto_nft_count INTEGER := 0;
  v_level1_rate NUMERIC := 0.20;
  v_level2_rate NUMERIC := 0.10;
  v_level3_rate NUMERIC := 0.05;
  v_next_sequence INTEGER;
  v_year_month TEXT;
BEGIN
  -- ========================================
  -- STEP 1: 入力検証
  -- ========================================
  IF p_year IS NULL OR p_month IS NULL THEN
    RETURN QUERY SELECT 'ERROR'::TEXT, '年月が指定されていません'::TEXT, NULL::JSONB;
    RETURN;
  END IF;

  IF p_month < 1 OR p_month > 12 THEN
    RETURN QUERY SELECT 'ERROR'::TEXT, '月は1-12の範囲で指定してください'::TEXT, NULL::JSONB;
    RETURN;
  END IF;

  -- 対象期間を計算
  v_start_date := make_date(p_year, p_month, 1);
  v_end_date := (v_start_date + INTERVAL '1 month - 1 day')::DATE;
  v_year_month := format('%s-%s', p_year, LPAD(p_month::TEXT, 2, '0'));

  -- 既存データの確認
  IF EXISTS (
    SELECT 1 FROM monthly_referral_profit
    WHERE year_month = v_year_month
  ) THEN
    IF NOT p_overwrite THEN
      RETURN QUERY SELECT 'ERROR'::TEXT,
        format('%s年%s月の紹介報酬は既に計算済みです（上書きする場合はp_overwrite=trueを指定）', p_year, p_month)::TEXT,
        NULL::JSONB;
      RETURN;
    ELSE
      -- 既存データを削除
      DELETE FROM monthly_referral_profit WHERE year_month = v_year_month;
    END IF;
  END IF;

  -- ========================================
  -- STEP 2: 各ユーザーの月次日利合計を計算（プラス・マイナス両方含む）
  -- ========================================
  DROP TABLE IF EXISTS temp_monthly_profit;
  CREATE TEMP TABLE temp_monthly_profit AS
  SELECT
    user_id,
    SUM(daily_profit) as monthly_profit
  FROM nft_daily_profit
  WHERE date >= v_start_date
    AND date <= v_end_date
  GROUP BY user_id
  HAVING SUM(daily_profit) > 0;  -- 月末合計がプラスの場合のみ

  -- ========================================
  -- STEP 3: Level 1 紹介報酬を計算
  -- ========================================
  FOR v_user_record IN
    SELECT DISTINCT u.user_id
    FROM users u
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= v_end_date
      AND EXISTS (
        SELECT 1 FROM users child
        WHERE child.referrer_user_id = u.user_id
      )
  LOOP
    FOR v_child_record IN
      SELECT
        child.user_id as child_user_id,
        COALESCE(tmp.monthly_profit, 0) as child_monthly_profit
      FROM users child
      LEFT JOIN temp_monthly_profit tmp ON tmp.user_id = child.user_id
      WHERE child.referrer_user_id = v_user_record.user_id
        AND child.has_approved_nft = true
        AND child.operation_start_date IS NOT NULL
        AND child.operation_start_date <= v_end_date
        AND COALESCE(tmp.monthly_profit, 0) > 0
    LOOP
      INSERT INTO monthly_referral_profit (
        user_id,
        year_month,
        referral_level,
        child_user_id,
        profit_amount,
        calculation_date,
        created_at
      ) VALUES (
        v_user_record.user_id,
        v_year_month,
        1,
        v_child_record.child_user_id,
        v_child_record.child_monthly_profit * v_level1_rate,
        v_end_date,
        NOW()
      );

      UPDATE affiliate_cycle
      SET
        cum_usdt = cum_usdt + (v_child_record.child_monthly_profit * v_level1_rate),
        available_usdt = CASE
          WHEN phase = 'USDT' THEN available_usdt + (v_child_record.child_monthly_profit * v_level1_rate)
          ELSE available_usdt
        END,
        updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_referral := v_total_referral + (v_child_record.child_monthly_profit * v_level1_rate);
      v_total_records := v_total_records + 1;
    END LOOP;
  END LOOP;

  -- ========================================
  -- STEP 4: Level 2 紹介報酬を計算
  -- ========================================
  FOR v_user_record IN
    SELECT DISTINCT u.user_id
    FROM users u
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= v_end_date
  LOOP
    FOR v_child_record IN
      SELECT
        child.user_id as child_user_id,
        COALESCE(tmp.monthly_profit, 0) as child_monthly_profit
      FROM users level1
      JOIN users child ON child.referrer_user_id = level1.user_id
      LEFT JOIN temp_monthly_profit tmp ON tmp.user_id = child.user_id
      WHERE level1.referrer_user_id = v_user_record.user_id
        AND level1.has_approved_nft = true
        AND child.has_approved_nft = true
        AND child.operation_start_date IS NOT NULL
        AND child.operation_start_date <= v_end_date
        AND COALESCE(tmp.monthly_profit, 0) > 0
    LOOP
      INSERT INTO monthly_referral_profit (
        user_id,
        year_month,
        referral_level,
        child_user_id,
        profit_amount,
        calculation_date,
        created_at
      ) VALUES (
        v_user_record.user_id,
        v_year_month,
        2,
        v_child_record.child_user_id,
        v_child_record.child_monthly_profit * v_level2_rate,
        v_end_date,
        NOW()
      );

      UPDATE affiliate_cycle
      SET
        cum_usdt = cum_usdt + (v_child_record.child_monthly_profit * v_level2_rate),
        available_usdt = CASE
          WHEN phase = 'USDT' THEN available_usdt + (v_child_record.child_monthly_profit * v_level2_rate)
          ELSE available_usdt
        END,
        updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_referral := v_total_referral + (v_child_record.child_monthly_profit * v_level2_rate);
      v_total_records := v_total_records + 1;
    END LOOP;
  END LOOP;

  -- ========================================
  -- STEP 5: Level 3 紹介報酬を計算
  -- ========================================
  FOR v_user_record IN
    SELECT DISTINCT u.user_id
    FROM users u
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= v_end_date
  LOOP
    FOR v_child_record IN
      SELECT
        child.user_id as child_user_id,
        COALESCE(tmp.monthly_profit, 0) as child_monthly_profit
      FROM users level1
      JOIN users level2 ON level2.referrer_user_id = level1.user_id
      JOIN users child ON child.referrer_user_id = level2.user_id
      LEFT JOIN temp_monthly_profit tmp ON tmp.user_id = child.user_id
      WHERE level1.referrer_user_id = v_user_record.user_id
        AND level1.has_approved_nft = true
        AND level2.has_approved_nft = true
        AND child.has_approved_nft = true
        AND child.operation_start_date IS NOT NULL
        AND child.operation_start_date <= v_end_date
        AND COALESCE(tmp.monthly_profit, 0) > 0
    LOOP
      INSERT INTO monthly_referral_profit (
        user_id,
        year_month,
        referral_level,
        child_user_id,
        profit_amount,
        calculation_date,
        created_at
      ) VALUES (
        v_user_record.user_id,
        v_year_month,
        3,
        v_child_record.child_user_id,
        v_child_record.child_monthly_profit * v_level3_rate,
        v_end_date,
        NOW()
      );

      UPDATE affiliate_cycle
      SET
        cum_usdt = cum_usdt + (v_child_record.child_monthly_profit * v_level3_rate),
        available_usdt = CASE
          WHEN phase = 'USDT' THEN available_usdt + (v_child_record.child_monthly_profit * v_level3_rate)
          ELSE available_usdt
        END,
        updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_referral := v_total_referral + (v_child_record.child_monthly_profit * v_level3_rate);
      v_total_records := v_total_records + 1;
    END LOOP;
  END LOOP;

  -- ========================================
  -- STEP 6: phaseを再計算 ★WHERE句を追加★
  -- ========================================
  UPDATE affiliate_cycle
  SET
    phase = CASE
      WHEN cum_usdt < 1100 THEN 'USDT'
      WHEN (FLOOR(cum_usdt / 1100)::int % 2) = 0 THEN 'USDT'
      ELSE 'HOLD'
    END,
    updated_at = NOW()
  WHERE cum_usdt >= 0;  -- ★修正: WHERE句を追加★

  -- ========================================
  -- STEP 7: NFT自動付与（cum_usdt >= 2200）
  -- ========================================
  FOR v_user_record IN
    SELECT
      ac.user_id,
      ac.cum_usdt,
      ac.auto_nft_count
    FROM affiliate_cycle ac
    JOIN users u ON ac.user_id = u.user_id
    WHERE ac.cum_usdt >= 2200
      AND u.has_approved_nft = true
  LOOP
    -- 次のnft_sequenceを計算
    SELECT COALESCE(MAX(nft_sequence), 0) + 1
    INTO v_next_sequence
    FROM nft_master
    WHERE user_id = v_user_record.user_id;

    -- NFT作成
    INSERT INTO nft_master (
      user_id,
      nft_sequence,
      nft_type,
      nft_value,
      acquired_date,
      buyback_date,
      operation_start_date
    ) VALUES (
      v_user_record.user_id,
      v_next_sequence,
      'auto',
      1000,
      v_end_date,
      NULL,
      calculate_operation_start_date(v_end_date)
    );

    -- purchasesに記録
    INSERT INTO purchases (
      user_id,
      nft_quantity,
      amount_usd,
      payment_status,
      admin_approved,
      admin_approved_at,
      cycle_number_at_purchase,
      is_auto_purchase
    ) VALUES (
      v_user_record.user_id,
      1,
      1100,
      'completed',
      true,
      NOW(),
      v_user_record.auto_nft_count + 1,
      true
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

    v_auto_nft_count := v_auto_nft_count + 1;
  END LOOP;

  -- ========================================
  -- STEP 8: 集計
  -- ========================================
  SELECT COUNT(DISTINCT user_id)
  INTO v_total_users
  FROM monthly_referral_profit
  WHERE year_month = v_year_month;

  -- 一時テーブルを削除
  DROP TABLE IF EXISTS temp_monthly_profit;

  -- ========================================
  -- STEP 9: 結果を返す
  -- ========================================
  RETURN QUERY SELECT
    'SUCCESS'::TEXT,
    format('%s年%s月の紹介報酬計算完了: %s名に総額$%s配布、NFT自動付与: %s件',
      p_year, p_month, v_total_users, ROUND(v_total_referral::NUMERIC, 2), v_auto_nft_count
    )::TEXT,
    jsonb_build_object(
      'year', p_year,
      'month', p_month,
      'total_users', v_total_users,
      'total_records', v_total_records,
      'total_amount', v_total_referral,
      'auto_nft_count', v_auto_nft_count,
      'period', format('%s〜%s', v_start_date, v_end_date)
    );

EXCEPTION
  WHEN OTHERS THEN
    DROP TABLE IF EXISTS temp_monthly_profit;
    RETURN QUERY SELECT
      'ERROR'::TEXT,
      format('エラー: %s', SQLERRM)::TEXT,
      jsonb_build_object('error_detail', SQLERRM);
END;
$function$;

SELECT 'process_monthly_referral_reward関数を修正しました（WHERE句追加 + ペガサス除外）' as result;
