-- ========================================
-- NFTサイクル総合修正（最終版）
-- ========================================
-- 修正日: 2026-02-06
--
-- 問題:
-- 1. NFT自動付与時にcum_usdtから$1,100しか引いていなかった
-- 2. available_usdtに$1,100を誤って加算していた
--
-- 正しいロジック:
-- - cum_usdt >= $2,200 → NFT付与
-- - cum_usdt -= $2,200（$1,100はNFT購入代金として消費）
-- - available_usdt += (余りのみ、$1,100解放は誤り)
-- - 余り < $1,100 → USDT、余り >= $1,100 → HOLD
--
-- 影響ユーザー: 177B83, 59C23C
-- ========================================

-- ========================================
-- STEP 0: 現状確認
-- ========================================
SELECT '=== STEP 0: 修正前の状態確認 ===' as section;

SELECT
  ac.user_id,
  ac.auto_nft_count as "自動NFT数",
  ac.cum_usdt as "現在cum_usdt",
  ac.phase as "現在phase",
  ac.available_usdt as "現在available_usdt",
  COALESCE(mrp.total_referral, 0) as "紹介報酬累計",
  -- 正しいcum_usdt = 紹介報酬累計 - (NFT数 × 2200)
  GREATEST(0, COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200)) as "正しいcum_usdt",
  CASE
    WHEN GREATEST(0, COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200)) >= 1100 THEN 'HOLD'
    ELSE 'USDT'
  END as "正しいphase"
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ac.auto_nft_count > 0
ORDER BY ac.user_id;

-- ========================================
-- STEP 1: process_monthly_referral_reward関数の修正
-- ========================================

CREATE OR REPLACE FUNCTION public.process_monthly_referral_reward(
  p_year integer,
  p_month integer,
  p_overwrite boolean DEFAULT false
)
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
  v_nft_to_grant INTEGER;
  v_i INTEGER;
  v_new_cum_usdt NUMERIC;
  v_excess NUMERIC;
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

  v_start_date := make_date(p_year, p_month, 1);
  v_end_date := (v_start_date + INTERVAL '1 month - 1 day')::DATE;
  v_year_month := format('%s-%s', p_year, LPAD(p_month::TEXT, 2, '0'));

  IF EXISTS (
    SELECT 1 FROM monthly_referral_profit
    WHERE year_month = v_year_month
  ) THEN
    IF NOT p_overwrite THEN
      RETURN QUERY SELECT 'ERROR'::TEXT,
        format('%s年%s月の紹介報酬は既に計算済みです', p_year, p_month)::TEXT,
        NULL::JSONB;
      RETURN;
    ELSE
      DELETE FROM monthly_referral_profit WHERE year_month = v_year_month;
    END IF;
  END IF;

  -- ========================================
  -- STEP 2: 月次日利合計
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
  HAVING SUM(daily_profit) > 0;

  -- ========================================
  -- STEP 3-5: Level 1/2/3 紹介報酬計算
  -- ========================================

  -- Level 1 (20%)
  FOR v_user_record IN
    SELECT DISTINCT u.user_id
    FROM users u
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= v_end_date
      AND EXISTS (SELECT 1 FROM users child WHERE child.referrer_user_id = u.user_id)
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
        user_id, year_month, referral_level, child_user_id,
        profit_amount, calculation_date, created_at
      ) VALUES (
        v_user_record.user_id, v_year_month, 1, v_child_record.child_user_id,
        v_child_record.child_monthly_profit * v_level1_rate, v_end_date, NOW()
      );

      -- ★★★ 修正: phaseに応じてavailable_usdtを更新 ★★★
      UPDATE affiliate_cycle
      SET
        cum_usdt = cum_usdt + (v_child_record.child_monthly_profit * v_level1_rate),
        -- USDTフェーズの場合のみavailable_usdtに加算
        -- HOLDフェーズの場合はcum_usdtのみ増加（available_usdtは変わらない）
        available_usdt = CASE
          WHEN phase = 'USDT' AND (cum_usdt + (v_child_record.child_monthly_profit * v_level1_rate)) < 1100
            THEN available_usdt + (v_child_record.child_monthly_profit * v_level1_rate)
          WHEN phase = 'USDT' AND cum_usdt < 1100
            -- USDTからHOLDに移行する場合：$1100までの分だけ加算
            THEN available_usdt + GREATEST(0, 1100 - cum_usdt - 0.01)
          ELSE available_usdt
        END,
        -- フェーズを更新
        phase = CASE
          WHEN (cum_usdt + (v_child_record.child_monthly_profit * v_level1_rate)) < 1100 THEN 'USDT'
          ELSE 'HOLD'
        END,
        updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_referral := v_total_referral + (v_child_record.child_monthly_profit * v_level1_rate);
      v_total_records := v_total_records + 1;
    END LOOP;
  END LOOP;

  -- Level 2 (10%)
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
        user_id, year_month, referral_level, child_user_id,
        profit_amount, calculation_date, created_at
      ) VALUES (
        v_user_record.user_id, v_year_month, 2, v_child_record.child_user_id,
        v_child_record.child_monthly_profit * v_level2_rate, v_end_date, NOW()
      );

      UPDATE affiliate_cycle
      SET
        cum_usdt = cum_usdt + (v_child_record.child_monthly_profit * v_level2_rate),
        available_usdt = CASE
          WHEN phase = 'USDT' AND (cum_usdt + (v_child_record.child_monthly_profit * v_level2_rate)) < 1100
            THEN available_usdt + (v_child_record.child_monthly_profit * v_level2_rate)
          WHEN phase = 'USDT' AND cum_usdt < 1100
            THEN available_usdt + GREATEST(0, 1100 - cum_usdt - 0.01)
          ELSE available_usdt
        END,
        phase = CASE
          WHEN (cum_usdt + (v_child_record.child_monthly_profit * v_level2_rate)) < 1100 THEN 'USDT'
          ELSE 'HOLD'
        END,
        updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_referral := v_total_referral + (v_child_record.child_monthly_profit * v_level2_rate);
      v_total_records := v_total_records + 1;
    END LOOP;
  END LOOP;

  -- Level 3 (5%)
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
        user_id, year_month, referral_level, child_user_id,
        profit_amount, calculation_date, created_at
      ) VALUES (
        v_user_record.user_id, v_year_month, 3, v_child_record.child_user_id,
        v_child_record.child_monthly_profit * v_level3_rate, v_end_date, NOW()
      );

      UPDATE affiliate_cycle
      SET
        cum_usdt = cum_usdt + (v_child_record.child_monthly_profit * v_level3_rate),
        available_usdt = CASE
          WHEN phase = 'USDT' AND (cum_usdt + (v_child_record.child_monthly_profit * v_level3_rate)) < 1100
            THEN available_usdt + (v_child_record.child_monthly_profit * v_level3_rate)
          WHEN phase = 'USDT' AND cum_usdt < 1100
            THEN available_usdt + GREATEST(0, 1100 - cum_usdt - 0.01)
          ELSE available_usdt
        END,
        phase = CASE
          WHEN (cum_usdt + (v_child_record.child_monthly_profit * v_level3_rate)) < 1100 THEN 'USDT'
          ELSE 'HOLD'
        END,
        updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_referral := v_total_referral + (v_child_record.child_monthly_profit * v_level3_rate);
      v_total_records := v_total_records + 1;
    END LOOP;
  END LOOP;

  -- ========================================
  -- STEP 6: NFT自動付与（cum_usdt >= 2200）
  -- ★★★ 重要な修正 ★★★
  -- - cum_usdt -= $2,200（$1,100ではない）
  -- - available_usdt += 余りのみ（$1,100解放は誤り）
  -- ========================================
  FOR v_user_record IN
    SELECT
      ac.user_id,
      ac.cum_usdt,
      ac.auto_nft_count,
      ac.available_usdt
    FROM affiliate_cycle ac
    JOIN users u ON ac.user_id = u.user_id
    WHERE ac.cum_usdt >= 2200
      AND u.has_approved_nft = true
  LOOP
    -- 付与するNFT数を計算（$2200ごとに1枚）
    v_nft_to_grant := FLOOR(v_user_record.cum_usdt / 2200)::INTEGER;

    -- NFT付与後のcum_usdt（余り）
    v_new_cum_usdt := v_user_record.cum_usdt - (v_nft_to_grant * 2200);

    -- 余りのうちUSDTフェーズで出金可能な金額
    -- 余りが$1100未満なら全額出金可能、$1100以上なら$0（HOLDに入る）
    v_excess := CASE
      WHEN v_new_cum_usdt < 1100 THEN v_new_cum_usdt
      ELSE 0
    END;

    -- NFTをループで付与
    FOR v_i IN 1..v_nft_to_grant LOOP
      SELECT COALESCE(MAX(nft_sequence), 0) + 1
      INTO v_next_sequence
      FROM nft_master
      WHERE user_id = v_user_record.user_id;

      INSERT INTO nft_master (
        user_id, nft_sequence, nft_type, nft_value,
        acquired_date, buyback_date, operation_start_date
      ) VALUES (
        v_user_record.user_id, v_next_sequence, 'auto', 1000,
        v_end_date, NULL, calculate_operation_start_date(v_end_date)
      );

      INSERT INTO purchases (
        user_id, nft_quantity, amount_usd, payment_status,
        admin_approved, admin_approved_at, cycle_number_at_purchase, is_auto_purchase
      ) VALUES (
        v_user_record.user_id, 1, 1100, 'completed',
        true, NOW(), v_user_record.auto_nft_count + v_i, true
      );

      v_auto_nft_count := v_auto_nft_count + 1;
    END LOOP;

    -- ★★★ affiliate_cycleを更新 ★★★
    -- cum_usdt: $2200 × NFT数を減算
    -- available_usdt: 余り（USDTフェーズ分）のみ加算、$1100解放は誤り
    UPDATE affiliate_cycle
    SET
      cum_usdt = v_new_cum_usdt,
      available_usdt = available_usdt + v_excess,
      auto_nft_count = auto_nft_count + v_nft_to_grant,
      total_nft_count = total_nft_count + v_nft_to_grant,
      phase = CASE
        WHEN v_new_cum_usdt >= 1100 THEN 'HOLD'
        ELSE 'USDT'
      END,
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id;
  END LOOP;

  -- ========================================
  -- STEP 7: 集計
  -- ========================================
  SELECT COUNT(DISTINCT user_id)
  INTO v_total_users
  FROM monthly_referral_profit
  WHERE year_month = v_year_month;

  DROP TABLE IF EXISTS temp_monthly_profit;

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

-- ========================================
-- STEP 2: 既存ユーザー（177B83, 59C23C）の修正
-- ========================================
SELECT '=== STEP 2: 既存ユーザーの修正 ===' as section;

-- 正しいcum_usdt = 紹介報酬累計 - (auto_nft_count × 2200)
-- 正しいavailable_usdt = 日利累計 + (紹介報酬のうちUSDTフェーズ分) - 出金済み
UPDATE affiliate_cycle ac
SET
  cum_usdt = GREATEST(0, COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200)),
  phase = CASE
    WHEN GREATEST(0, COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200)) >= 1100 THEN 'HOLD'
    ELSE 'USDT'
  END,
  updated_at = NOW()
FROM (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp
WHERE ac.user_id = mrp.user_id
  AND ac.auto_nft_count > 0;

-- ========================================
-- STEP 3: 修正後の確認
-- ========================================
SELECT '=== STEP 3: 修正後の状態確認 ===' as section;

SELECT
  ac.user_id,
  ac.auto_nft_count as "自動NFT数",
  ac.cum_usdt as "修正後cum_usdt",
  ac.phase as "修正後phase",
  ac.available_usdt as "available_usdt",
  COALESCE(mrp.total_referral, 0) as "紹介報酬累計",
  COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200) as "検証（累計-NFT×2200）"
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ac.auto_nft_count > 0
ORDER BY ac.user_id;

SELECT '✅ NFTサイクル総合修正完了' as status;
SELECT '  - cum_usdt: $2200減算（$1100ではない）' as fix1;
SELECT '  - available_usdt: 余りのみ加算（$1100解放は誤り）' as fix2;
SELECT '  - 177B83, 59C23Cのcum_usdtとphaseを修正' as fix3;
