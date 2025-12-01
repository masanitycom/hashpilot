-- ========================================
-- 紹介報酬計算の修正：プラス日利のみ → 全日利合計
-- ========================================
--
-- 問題：
-- process_monthly_referral_reward関数が「プラス日利のみ」で計算していた
-- WHERE daily_profit > 0  ← この条件が間違い
--
-- 正しい仕様：
-- 月末の合計利益（プラス・マイナス含む）で計算
-- 日々のマイナスも月末合計に反映される
--
-- 影響：
-- 11月の紹介報酬が実際より高く計算されている
-- 例：9A3A16は$4,994の利益だが、$8,525で計算されていた
-- ========================================

CREATE OR REPLACE FUNCTION process_monthly_referral_reward(
  p_year INTEGER,
  p_month INTEGER,
  p_overwrite BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(status TEXT, message TEXT, details JSONB)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_start_date DATE;
  v_end_date DATE;
  v_user_record RECORD;
  v_child_record RECORD;
  v_total_referral NUMERIC := 0;
  v_total_users INTEGER := 0;
  v_total_records INTEGER := 0;
  v_level1_rate NUMERIC := 0.20;
  v_level2_rate NUMERIC := 0.10;
  v_level3_rate NUMERIC := 0.05;
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

  -- 既存データの確認
  IF EXISTS (
    SELECT 1 FROM user_referral_profit_monthly
    WHERE year = p_year AND month = p_month
  ) THEN
    IF NOT p_overwrite THEN
      RETURN QUERY SELECT 'ERROR'::TEXT,
        format('%s年%s月の紹介報酬は既に計算済みです（上書きする場合はp_overwrite=trueを指定）', p_year, p_month)::TEXT,
        NULL::JSONB;
      RETURN;
    ELSE
      -- 既存データを削除
      DELETE FROM user_referral_profit_monthly
      WHERE year = p_year AND month = p_month;

      -- affiliate_cycleから既存の紹介報酬を減算
      UPDATE affiliate_cycle ac
      SET
        cum_usdt = cum_usdt - COALESCE((
          SELECT SUM(profit_amount)
          FROM user_referral_profit_monthly urpm
          WHERE urpm.user_id = ac.user_id
            AND urpm.year = p_year
            AND urpm.month = p_month
        ), 0),
        available_usdt = available_usdt - COALESCE((
          SELECT SUM(profit_amount)
          FROM user_referral_profit_monthly urpm
          WHERE urpm.user_id = ac.user_id
            AND urpm.year = p_year
            AND urpm.month = p_month
        ), 0);
    END IF;
  END IF;

  -- ========================================
  -- STEP 2: 各ユーザーの月次日利合計を計算
  -- ========================================
  -- ✅ 修正：プラス・マイナス両方を含める（daily_profit > 0 を削除）
  CREATE TEMP TABLE temp_monthly_profit AS
  SELECT
    user_id,
    SUM(daily_profit) as monthly_profit
  FROM user_daily_profit
  WHERE date >= v_start_date
    AND date <= v_end_date
  GROUP BY user_id;

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
        AND COALESCE(tmp.monthly_profit, 0) > 0  -- プラス利益の場合のみ紹介報酬
    LOOP
      INSERT INTO user_referral_profit_monthly (
        user_id,
        year,
        month,
        referral_level,
        child_user_id,
        child_monthly_profit,
        profit_amount
      ) VALUES (
        v_user_record.user_id,
        p_year,
        p_month,
        1,
        v_child_record.child_user_id,
        v_child_record.child_monthly_profit,
        v_child_record.child_monthly_profit * v_level1_rate
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

  -- ========================================
  -- STEP 4: Level 2 紹介報酬を計算
  -- ========================================
  FOR v_user_record IN
    SELECT DISTINCT u.user_id
    FROM users u
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= v_end_date
      AND EXISTS (
        SELECT 1 FROM users level1
        WHERE level1.referrer_user_id = u.user_id
          AND EXISTS (
            SELECT 1 FROM users child
            WHERE child.referrer_user_id = level1.user_id
          )
      )
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
      INSERT INTO user_referral_profit_monthly (
        user_id,
        year,
        month,
        referral_level,
        child_user_id,
        child_monthly_profit,
        profit_amount
      ) VALUES (
        v_user_record.user_id,
        p_year,
        p_month,
        2,
        v_child_record.child_user_id,
        v_child_record.child_monthly_profit,
        v_child_record.child_monthly_profit * v_level2_rate
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

  -- ========================================
  -- STEP 5: Level 3 紹介報酬を計算
  -- ========================================
  FOR v_user_record IN
    SELECT DISTINCT u.user_id
    FROM users u
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= v_end_date
      AND EXISTS (
        SELECT 1 FROM users level1
        WHERE level1.referrer_user_id = u.user_id
          AND EXISTS (
            SELECT 1 FROM users level2
            WHERE level2.referrer_user_id = level1.user_id
              AND EXISTS (
                SELECT 1 FROM users child
                WHERE child.referrer_user_id = level2.user_id
              )
          )
      )
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
      INSERT INTO user_referral_profit_monthly (
        user_id,
        year,
        month,
        referral_level,
        child_user_id,
        child_monthly_profit,
        profit_amount
      ) VALUES (
        v_user_record.user_id,
        p_year,
        p_month,
        3,
        v_child_record.child_user_id,
        v_child_record.child_monthly_profit,
        v_child_record.child_monthly_profit * v_level3_rate
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

  -- ========================================
  -- STEP 6: 集計
  -- ========================================
  SELECT COUNT(DISTINCT user_id)
  INTO v_total_users
  FROM user_referral_profit_monthly
  WHERE year = p_year AND month = p_month;

  -- 一時テーブルを削除
  DROP TABLE temp_monthly_profit;

  -- ========================================
  -- STEP 7: タスクポップアップ用のフラグを設定
  -- ========================================
  PERFORM mark_referral_reward_calculated(p_year, p_month);

  -- ========================================
  -- STEP 8: 結果を返す
  -- ========================================
  RETURN QUERY SELECT
    'SUCCESS'::TEXT,
    format('%s年%s月の紹介報酬計算完了: %s名に総額$%s配布',
      p_year, p_month, v_total_users, v_total_referral::TEXT
    )::TEXT,
    jsonb_build_object(
      'year', p_year,
      'month', p_month,
      'total_users', v_total_users,
      'total_records', v_total_records,
      'total_amount', v_total_referral,
      'period', format('%s～%s', v_start_date, v_end_date)
    );
END;
$$;

-- 確認
SELECT 'process_monthly_referral_reward関数を修正しました（プラス・マイナス両方を含める）' as status;
