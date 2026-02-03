-- ========================================
-- ペガサスユーザーへの誤配布削除 + 除外条件復元
-- ========================================
-- 問題: 1/20〜1/25にペガサスユーザー61人に日利が誤配布された
-- 原因: ペガサス除外条件が削除されていた
-- 対応: 1. 誤配布データ削除 2. affiliate_cycle修正 3. 除外条件復元

-- ========================================
-- STEP 1: 誤配布の確認
-- ========================================
SELECT '=== STEP 1: 誤配布の確認 ===' as section;
SELECT
  COUNT(*) as 削除対象レコード数,
  COUNT(DISTINCT user_id) as ユーザー数,
  ROUND(SUM(daily_profit)::numeric, 2) as 誤配布合計
FROM nft_daily_profit
WHERE user_id IN (
  SELECT user_id FROM users WHERE is_pegasus_exchange = true
);

-- ========================================
-- STEP 2: affiliate_cycle修正（available_usdtを戻す）
-- ========================================
SELECT '=== STEP 2: affiliate_cycle修正 ===' as section;

-- 各ユーザーの誤配布額を計算してavailable_usdtから差し引く
WITH pegasus_wrong_profit AS (
  SELECT
    user_id,
    SUM(daily_profit) as wrong_profit
  FROM nft_daily_profit
  WHERE user_id IN (
    SELECT user_id FROM users WHERE is_pegasus_exchange = true
  )
  GROUP BY user_id
)
UPDATE affiliate_cycle ac
SET
  available_usdt = available_usdt - pwp.wrong_profit,
  updated_at = NOW()
FROM pegasus_wrong_profit pwp
WHERE ac.user_id = pwp.user_id;

SELECT '更新完了: affiliate_cycleからマイナス分を戻しました' as result;

-- ========================================
-- STEP 3: 誤配布レコード削除
-- ========================================
SELECT '=== STEP 3: 誤配布レコード削除 ===' as section;

DELETE FROM nft_daily_profit
WHERE user_id IN (
  SELECT user_id FROM users WHERE is_pegasus_exchange = true
);

SELECT '削除完了: ペガサスユーザーの日利レコードを削除しました' as result;

-- ========================================
-- STEP 4: 関数にペガサス除外条件を復元
-- ========================================
SELECT '=== STEP 4: process_daily_yield_v2にペガサス除外条件を復元 ===' as section;

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
  v_total_distributed NUMERIC := 0;
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
      DELETE FROM stock_fund WHERE date = p_date;
    END IF;
  END IF;

  -- NFTごとのoperation_start_dateをチェック
  -- ★ペガサス除外条件を含める（is_pegasus_exchange = true は対象外）
  SELECT COUNT(*)
  INTO v_total_nft_count
  FROM nft_master nm
  JOIN users u ON nm.user_id = u.user_id
  WHERE nm.buyback_date IS NULL
    AND nm.operation_start_date IS NOT NULL
    AND nm.operation_start_date <= p_date
    AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);  -- ★ペガサス除外

  IF v_total_nft_count = 0 THEN
    RETURN QUERY SELECT 'ERROR'::TEXT, '運用中のNFTが見つかりません'::TEXT, NULL::JSONB;
    RETURN;
  END IF;

  v_profit_per_nft := p_total_profit_amount / v_total_nft_count;

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

  v_distribution_dividend := v_daily_pnl * 0.60;
  v_distribution_affiliate := v_daily_pnl * 0.30;
  v_distribution_stock := v_daily_pnl * 0.10;

  INSERT INTO daily_yield_log_v2 (
    date, total_profit_amount, total_nft_count, profit_per_nft,
    cumulative_gross_profit, fee_rate, cumulative_fee, cumulative_net_profit,
    daily_pnl, distribution_dividend, distribution_affiliate, distribution_stock,
    is_month_end, created_by
  ) VALUES (
    p_date, p_total_profit_amount, v_total_nft_count, v_profit_per_nft,
    v_cumulative_gross, v_fee_rate, v_cumulative_fee, v_cumulative_net,
    v_daily_pnl, v_distribution_dividend, v_distribution_affiliate, v_distribution_stock,
    EXTRACT(DAY FROM (p_date + INTERVAL '1 day')) = 1, current_user
  );

  -- 個人利益配布（60%）
  -- ★ペガサス除外条件を含める
  IF v_distribution_dividend != 0 THEN
    FOR v_user_record IN
      SELECT u.user_id, u.id as user_uuid, COUNT(nm.id) as nft_count
      FROM users u
      JOIN nft_master nm ON nm.user_id = u.user_id
      WHERE nm.buyback_date IS NULL
        AND nm.operation_start_date IS NOT NULL
        AND nm.operation_start_date <= p_date
        AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)  -- ★ペガサス除外
      GROUP BY u.user_id, u.id
    LOOP
      v_user_profit := (v_distribution_dividend / v_total_nft_count) * v_user_record.nft_count;

      FOR v_nft_record IN
        SELECT id as nft_id
        FROM nft_master
        WHERE user_id = v_user_record.user_id
          AND buyback_date IS NULL
          AND operation_start_date IS NOT NULL
          AND operation_start_date <= p_date
      LOOP
        INSERT INTO nft_daily_profit (
          nft_id, user_id, date, daily_profit, yield_rate, user_rate,
          base_amount, phase, created_at
        ) VALUES (
          v_nft_record.nft_id, v_user_record.user_id, p_date,
          v_user_profit / v_user_record.nft_count, NULL, NULL,
          1000, 'DIVIDEND', NOW()
        );
      END LOOP;

      UPDATE affiliate_cycle
      SET available_usdt = available_usdt + v_user_profit, updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_distributed := v_total_distributed + v_user_profit;
    END LOOP;
  END IF;

  -- 日次紹介報酬は削除（月次で計算）

  -- ストック資金配布（10%）
  -- ★ペガサス除外条件を含める
  IF v_distribution_stock != 0 THEN
    FOR v_user_record IN
      SELECT u.user_id, COUNT(nm.id) as nft_count
      FROM users u
      JOIN nft_master nm ON nm.user_id = u.user_id
      WHERE nm.buyback_date IS NULL
        AND nm.operation_start_date IS NOT NULL
        AND nm.operation_start_date <= p_date
        AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)  -- ★ペガサス除外
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

  RETURN QUERY SELECT
    'SUCCESS'::TEXT,
    format('日利処理完了: %s', p_date)::TEXT,
    jsonb_build_object(
      'date', p_date,
      'total_profit_amount', p_total_profit_amount,
      'total_nft_count', v_total_nft_count,
      'profit_per_nft', ROUND(v_profit_per_nft, 6),
      'daily_pnl', ROUND(v_daily_pnl, 2),
      'distribution_dividend', ROUND(v_distribution_dividend, 2),
      'distribution_affiliate', ROUND(v_distribution_affiliate, 2),
      'distribution_stock', ROUND(v_distribution_stock, 2),
      'total_distributed', ROUND(v_total_distributed, 2),
      'total_stock', ROUND(v_total_stock, 2),
      'referral_count', 0,
      'total_referral', 0,
      'auto_nft_count', 0,
      'is_test_mode', p_is_test_mode
    );
END;
$$;

SELECT 'process_daily_yield_v2にペガサス除外条件を復元しました' as result;

-- ========================================
-- STEP 5: process_monthly_referral_rewardにもペガサス除外条件を復元
-- ========================================
SELECT '=== STEP 5: process_monthly_referral_rewardにペガサス除外条件を復元 ===' as section;

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
      AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)  -- ★ペガサス除外
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
        AND (child.is_pegasus_exchange = FALSE OR child.is_pegasus_exchange IS NULL)  -- ★ペガサス除外
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
      AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)  -- ★ペガサス除外
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
        AND (child.is_pegasus_exchange = FALSE OR child.is_pegasus_exchange IS NULL)  -- ★ペガサス除外
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
      AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)  -- ★ペガサス除外
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
        AND (child.is_pegasus_exchange = FALSE OR child.is_pegasus_exchange IS NULL)  -- ★ペガサス除外
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
  WHERE cum_usdt >= 0;  -- ★WHERE句追加

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
      AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)  -- ★ペガサス除外
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

SELECT 'process_monthly_referral_rewardにペガサス除外条件を復元しました' as result;

-- ========================================
-- STEP 6: 確認
-- ========================================
SELECT '=== STEP 6: 修正後の確認 ===' as section;
SELECT
  COUNT(*) as ペガサスユーザーの日利レコード数
FROM nft_daily_profit
WHERE user_id IN (
  SELECT user_id FROM users WHERE is_pegasus_exchange = true
);
