-- ========================================
-- 2026年1月 紹介報酬計算（手動実行用）
-- ========================================

DO $$
DECLARE
  v_year_month TEXT := '2026-01';
  v_start_date DATE := '2026-01-01';
  v_end_date DATE := '2026-01-31';
  v_level1_rate NUMERIC := 0.20;
  v_level2_rate NUMERIC := 0.10;
  v_level3_rate NUMERIC := 0.05;
  v_user_record RECORD;
  v_child_record RECORD;
  v_total_referral NUMERIC := 0;
  v_total_records INTEGER := 0;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '2026年1月 紹介報酬計算開始';
  RAISE NOTICE '========================================';

  -- 既存の1月データを削除（再実行対応）
  DELETE FROM monthly_referral_profit
  WHERE year_month = v_year_month;

  RAISE NOTICE '既存データを削除しました';

  -- 各ユーザーの月次日利合計を一時テーブルに格納
  DROP TABLE IF EXISTS temp_jan_profit;
  CREATE TEMP TABLE temp_jan_profit AS
  SELECT
    user_id,
    SUM(daily_profit) as monthly_profit
  FROM nft_daily_profit
  WHERE date >= v_start_date AND date <= v_end_date
  GROUP BY user_id;

  RAISE NOTICE '月次日利合計を計算しました';

  -- ========================================
  -- Level 1 紹介報酬
  -- ========================================
  FOR v_user_record IN
    SELECT DISTINCT u.user_id
    FROM users u
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= v_end_date
      AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
  LOOP
    FOR v_child_record IN
      SELECT
        child.user_id as child_user_id,
        COALESCE(tmp.monthly_profit, 0) as child_monthly_profit
      FROM users child
      LEFT JOIN temp_jan_profit tmp ON tmp.user_id = child.user_id
      WHERE child.referrer_user_id = v_user_record.user_id
        AND child.has_approved_nft = true
        AND child.operation_start_date IS NOT NULL
        AND child.operation_start_date <= v_end_date
        AND (child.is_pegasus_exchange = false OR child.is_pegasus_exchange IS NULL)
        AND COALESCE(tmp.monthly_profit, 0) > 0
    LOOP
      INSERT INTO monthly_referral_profit (
        user_id,
        year_month,
        referral_level,
        child_user_id,
        profit_amount,
        calculation_date
      ) VALUES (
        v_user_record.user_id,
        v_year_month,
        1,
        v_child_record.child_user_id,
        v_child_record.child_monthly_profit * v_level1_rate,
        v_end_date
      );

      UPDATE affiliate_cycle
      SET
        cum_usdt = cum_usdt + (v_child_record.child_monthly_profit * v_level1_rate),
        available_usdt = available_usdt + (v_child_record.child_monthly_profit * v_level1_rate),
        updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_referral := v_total_referral + (v_child_record.child_monthly_profit * v_level1_rate);
      v_total_records := v_total_records + 1;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'Level 1 完了';

  -- ========================================
  -- Level 2 紹介報酬
  -- ========================================
  FOR v_user_record IN
    SELECT DISTINCT u.user_id
    FROM users u
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= v_end_date
      AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
  LOOP
    FOR v_child_record IN
      SELECT
        child.user_id as child_user_id,
        COALESCE(tmp.monthly_profit, 0) as child_monthly_profit
      FROM users level1
      JOIN users child ON child.referrer_user_id = level1.user_id
      LEFT JOIN temp_jan_profit tmp ON tmp.user_id = child.user_id
      WHERE level1.referrer_user_id = v_user_record.user_id
        AND level1.has_approved_nft = true
        AND child.has_approved_nft = true
        AND child.operation_start_date IS NOT NULL
        AND child.operation_start_date <= v_end_date
        AND (child.is_pegasus_exchange = false OR child.is_pegasus_exchange IS NULL)
        AND COALESCE(tmp.monthly_profit, 0) > 0
    LOOP
      INSERT INTO monthly_referral_profit (
        user_id,
        year_month,
        referral_level,
        child_user_id,
        profit_amount,
        calculation_date
      ) VALUES (
        v_user_record.user_id,
        v_year_month,
        2,
        v_child_record.child_user_id,
        v_child_record.child_monthly_profit * v_level2_rate,
        v_end_date
      );

      UPDATE affiliate_cycle
      SET
        cum_usdt = cum_usdt + (v_child_record.child_monthly_profit * v_level2_rate),
        available_usdt = available_usdt + (v_child_record.child_monthly_profit * v_level2_rate),
        updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_referral := v_total_referral + (v_child_record.child_monthly_profit * v_level2_rate);
      v_total_records := v_total_records + 1;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'Level 2 完了';

  -- ========================================
  -- Level 3 紹介報酬
  -- ========================================
  FOR v_user_record IN
    SELECT DISTINCT u.user_id
    FROM users u
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= v_end_date
      AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
  LOOP
    FOR v_child_record IN
      SELECT
        child.user_id as child_user_id,
        COALESCE(tmp.monthly_profit, 0) as child_monthly_profit
      FROM users level1
      JOIN users level2 ON level2.referrer_user_id = level1.user_id
      JOIN users child ON child.referrer_user_id = level2.user_id
      LEFT JOIN temp_jan_profit tmp ON tmp.user_id = child.user_id
      WHERE level1.referrer_user_id = v_user_record.user_id
        AND level1.has_approved_nft = true
        AND level2.has_approved_nft = true
        AND child.has_approved_nft = true
        AND child.operation_start_date IS NOT NULL
        AND child.operation_start_date <= v_end_date
        AND (child.is_pegasus_exchange = false OR child.is_pegasus_exchange IS NULL)
        AND COALESCE(tmp.monthly_profit, 0) > 0
    LOOP
      INSERT INTO monthly_referral_profit (
        user_id,
        year_month,
        referral_level,
        child_user_id,
        profit_amount,
        calculation_date
      ) VALUES (
        v_user_record.user_id,
        v_year_month,
        3,
        v_child_record.child_user_id,
        v_child_record.child_monthly_profit * v_level3_rate,
        v_end_date
      );

      UPDATE affiliate_cycle
      SET
        cum_usdt = cum_usdt + (v_child_record.child_monthly_profit * v_level3_rate),
        available_usdt = available_usdt + (v_child_record.child_monthly_profit * v_level3_rate),
        updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_referral := v_total_referral + (v_child_record.child_monthly_profit * v_level3_rate);
      v_total_records := v_total_records + 1;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'Level 3 完了';

  -- phase更新
  UPDATE affiliate_cycle
  SET phase = CASE
    WHEN (FLOOR(cum_usdt / 1100)::int % 2) = 0 THEN 'USDT'
    ELSE 'HOLD'
  END
  WHERE cum_usdt >= 0;

  RAISE NOTICE '========================================';
  RAISE NOTICE '完了: % 件、合計 $%', v_total_records, ROUND(v_total_referral, 2);
  RAISE NOTICE '========================================';

  DROP TABLE IF EXISTS temp_jan_profit;
END $$;

-- 結果確認
SELECT '=== 2026年1月 紹介報酬サマリー ===' as section;
SELECT
  referral_level as レベル,
  COUNT(*) as 件数,
  COUNT(DISTINCT user_id) as ユーザー数,
  ROUND(SUM(profit_amount)::numeric, 2) as 合計報酬
FROM monthly_referral_profit
WHERE year_month = '2026-01'
GROUP BY referral_level
ORDER BY referral_level;

SELECT
  '合計' as レベル,
  COUNT(*) as 件数,
  COUNT(DISTINCT user_id) as ユーザー数,
  ROUND(SUM(profit_amount)::numeric, 2) as 合計報酬
FROM monthly_referral_profit
WHERE year_month = '2026-01';
