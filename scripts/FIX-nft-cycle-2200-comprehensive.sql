-- ========================================
-- NFTサイクル修正（包括的）
-- ========================================
-- 問題: NFT自動付与時にcum_usdtから$1,100しか引いていない
-- 正しい: $2,200を引く（$1,100 NFT代 + $1,100 HOLD解放）
-- ========================================
-- 影響範囲:
-- 1. process_monthly_referral_reward関数
-- 2. 177B83, 59C23Cの手動修正
-- ========================================

-- ========================================
-- STEP 0: 現状確認
-- ========================================
SELECT '=== STEP 0: 修正前の状態確認 ===' as section;

-- 自動NFT付与ユーザーの現状
SELECT
  ac.user_id,
  ac.auto_nft_count as "自動NFT数",
  ac.cum_usdt as "現在cum_usdt",
  ac.phase as "現在phase",
  ac.available_usdt as "available_usdt",
  ac.withdrawn_referral_usdt as "出金済み紹介報酬",
  COALESCE(mrp.total_referral, 0) as "紹介報酬累計",
  -- 正しいcum_usdt = 紹介報酬累計 - (NFT数 × 2200)
  COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200) as "正しいcum_usdt"
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
-- NFT自動付与部分: cum_usdt - 1100 → cum_usdt - 2200
-- WHILEループ追加（累計$4400以上で複数NFT付与対応）
-- ========================================

CREATE OR REPLACE FUNCTION process_monthly_referral_reward(
  p_year INTEGER,
  p_month INTEGER
)
RETURNS TABLE(
  status TEXT,
  message TEXT,
  details JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_year_month TEXT;
  v_start_date DATE;
  v_end_date DATE;
  v_total_referral NUMERIC := 0;
  v_total_records INTEGER := 0;
  v_total_users INTEGER := 0;
  v_auto_nft_count INTEGER := 0;
  v_user_record RECORD;
  v_referrer_record RECORD;
  v_monthly_profit NUMERIC;
  v_referral_amount NUMERIC;
  v_new_cum_usdt NUMERIC;
  v_nft_to_grant INTEGER;
BEGIN
  -- 年月文字列を生成
  v_year_month := format('%s-%s', p_year, LPAD(p_month::TEXT, 2, '0'));
  v_start_date := make_date(p_year, p_month, 1);
  v_end_date := (v_start_date + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

  -- 既存データの削除（再計算のため）
  DELETE FROM monthly_referral_profit WHERE year_month = v_year_month;

  -- 一時テーブル: 月間個人利益
  CREATE TEMP TABLE IF NOT EXISTS temp_monthly_profit AS
  SELECT
    ndp.user_id,
    SUM(ndp.daily_profit) as monthly_profit
  FROM nft_daily_profit ndp
  JOIN users u ON ndp.user_id = u.user_id
  WHERE ndp.date >= v_start_date
    AND ndp.date <= v_end_date
    AND u.operation_start_date IS NOT NULL
    AND u.operation_start_date <= v_end_date
  GROUP BY ndp.user_id
  HAVING SUM(ndp.daily_profit) > 0;  -- プラスの場合のみ紹介報酬発生

  -- ========================================
  -- 紹介報酬計算（レベル1/2/3）
  -- ========================================
  FOR v_user_record IN
    SELECT
      tmp.user_id,
      tmp.monthly_profit,
      u.referrer_user_id
    FROM temp_monthly_profit tmp
    JOIN users u ON tmp.user_id = u.user_id
    WHERE u.referrer_user_id IS NOT NULL
  LOOP
    -- Level 1 (20%)
    IF v_user_record.referrer_user_id IS NOT NULL THEN
      v_referral_amount := v_user_record.monthly_profit * 0.20;

      INSERT INTO monthly_referral_profit (
        user_id, referral_from_user_id, year_month,
        profit_amount, referral_level, created_at
      ) VALUES (
        v_user_record.referrer_user_id,
        v_user_record.user_id,
        v_year_month,
        v_referral_amount,
        1,
        NOW()
      );

      -- cum_usdt と available_usdt を更新
      UPDATE affiliate_cycle
      SET
        cum_usdt = cum_usdt + v_referral_amount,
        available_usdt = available_usdt + v_referral_amount,
        updated_at = NOW()
      WHERE user_id = v_user_record.referrer_user_id;

      v_total_referral := v_total_referral + v_referral_amount;
      v_total_records := v_total_records + 1;

      -- Level 2 (10%)
      SELECT referrer_user_id INTO v_referrer_record
      FROM users WHERE user_id = v_user_record.referrer_user_id;

      IF v_referrer_record.referrer_user_id IS NOT NULL THEN
        v_referral_amount := v_user_record.monthly_profit * 0.10;

        INSERT INTO monthly_referral_profit (
          user_id, referral_from_user_id, year_month,
          profit_amount, referral_level, created_at
        ) VALUES (
          v_referrer_record.referrer_user_id,
          v_user_record.user_id,
          v_year_month,
          v_referral_amount,
          2,
          NOW()
        );

        UPDATE affiliate_cycle
        SET
          cum_usdt = cum_usdt + v_referral_amount,
          available_usdt = available_usdt + v_referral_amount,
          updated_at = NOW()
        WHERE user_id = v_referrer_record.referrer_user_id;

        v_total_referral := v_total_referral + v_referral_amount;
        v_total_records := v_total_records + 1;

        -- Level 3 (5%)
        SELECT referrer_user_id INTO v_referrer_record
        FROM users WHERE user_id = v_referrer_record.referrer_user_id;

        IF v_referrer_record.referrer_user_id IS NOT NULL THEN
          v_referral_amount := v_user_record.monthly_profit * 0.05;

          INSERT INTO monthly_referral_profit (
            user_id, referral_from_user_id, year_month,
            profit_amount, referral_level, created_at
          ) VALUES (
            v_referrer_record.referrer_user_id,
            v_user_record.user_id,
            v_year_month,
            v_referral_amount,
            3,
            NOW()
          );

          UPDATE affiliate_cycle
          SET
            cum_usdt = cum_usdt + v_referral_amount,
            available_usdt = available_usdt + v_referral_amount,
            updated_at = NOW()
          WHERE user_id = v_referrer_record.referrer_user_id;

          v_total_referral := v_total_referral + v_referral_amount;
          v_total_records := v_total_records + 1;
        END IF;
      END IF;
    END IF;
  END LOOP;

  -- ========================================
  -- NFT自動付与（cum_usdt >= $2,200）
  -- ★ 修正: $1,100 → $2,200 を減算
  -- ★ WHILEループで複数NFT対応
  -- ========================================
  FOR v_user_record IN
    SELECT
      u.user_id,
      u.id as user_uuid,
      ac.cum_usdt,
      ac.auto_nft_count,
      ac.available_usdt
    FROM users u
    JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE ac.cum_usdt >= 2200
      AND u.operation_start_date IS NOT NULL
  LOOP
    -- 付与するNFT数を計算
    v_nft_to_grant := FLOOR(v_user_record.cum_usdt / 2200)::INTEGER;

    -- NFTを付与（ループで複数対応）
    FOR i IN 1..v_nft_to_grant LOOP
      -- nft_masterに追加
      INSERT INTO nft_master (
        user_id,
        nft_type,
        nft_sequence,
        acquired_date,
        operation_start_date,
        buyback_date
      ) VALUES (
        v_user_record.user_id,
        'auto',
        COALESCE((SELECT MAX(nft_sequence) FROM nft_master WHERE user_id = v_user_record.user_id), 0) + 1,
        CURRENT_DATE,
        calculate_operation_start_date(CURRENT_DATE),
        NULL
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
        v_user_record.auto_nft_count + i,
        true
      );

      v_auto_nft_count := v_auto_nft_count + 1;
    END LOOP;

    -- affiliate_cycleを更新
    -- ★ 修正: cum_usdt - (NFT数 × 2200)
    UPDATE affiliate_cycle
    SET
      cum_usdt = cum_usdt - (v_nft_to_grant * 2200),
      available_usdt = available_usdt + (v_nft_to_grant * 1100),
      auto_nft_count = auto_nft_count + v_nft_to_grant,
      total_nft_count = total_nft_count + v_nft_to_grant,
      phase = CASE
        WHEN (cum_usdt - (v_nft_to_grant * 2200)) >= 1100 THEN 'HOLD'
        ELSE 'USDT'
      END,
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id;

    -- usersテーブル更新
    UPDATE users
    SET
      has_approved_nft = true,
      total_purchases = total_purchases + (v_nft_to_grant * 1100),
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id;
  END LOOP;

  -- フェーズ再計算（全ユーザー）
  UPDATE affiliate_cycle
  SET phase = CASE
    WHEN cum_usdt >= 1100 THEN 'HOLD'
    ELSE 'USDT'
  END
  WHERE cum_usdt < 2200;

  -- 集計
  SELECT COUNT(DISTINCT user_id)
  INTO v_total_users
  FROM monthly_referral_profit
  WHERE year_month = v_year_month;

  -- 一時テーブルを削除
  DROP TABLE IF EXISTS temp_monthly_profit;

  -- 結果を返す
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
      'auto_nft_count', v_auto_nft_count
    );
END;
$$;

-- ========================================
-- STEP 2: 既存ユーザー（177B83, 59C23C）の手動修正
-- ========================================
SELECT '=== STEP 2: 既存ユーザーの修正 ===' as section;

-- 正しいcum_usdtを計算して更新
-- cum_usdt = 紹介報酬累計 - (auto_nft_count × 2200)
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
  COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200) as "計算値（検証）"
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ac.auto_nft_count > 0
ORDER BY ac.user_id;

SELECT 'NFTサイクル修正完了（cum_usdt - 2200）' as status;
