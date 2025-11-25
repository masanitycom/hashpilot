-- ========================================
-- STEP 3: V1システム関数の修正（DROP版）
-- ========================================
-- 既存の関数を削除してから新しい関数を作成
-- ========================================

-- 既存の関数を削除
DROP FUNCTION IF EXISTS process_daily_yield_with_cycles(date,numeric,numeric,boolean,boolean);

SELECT '✅ 既存の関数を削除しました' as status;

-- 新しい関数を作成
CREATE OR REPLACE FUNCTION process_daily_yield_with_cycles(
  p_date DATE,
  p_yield_rate NUMERIC,
  p_margin_rate NUMERIC,
  p_is_test_mode BOOLEAN DEFAULT FALSE,
  p_skip_validation BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
  message TEXT,
  details JSONB
) AS $$
DECLARE
  v_user_record RECORD;
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
BEGIN
  -- ========================================
  -- STEP 1: 入力検証
  -- ========================================
  IF NOT p_skip_validation THEN
    IF p_date > CURRENT_DATE THEN
      RAISE EXCEPTION '未来の日付には日利を設定できません';
    END IF;

    IF p_yield_rate < -10 OR p_yield_rate > 10 THEN
      RAISE EXCEPTION '日利率は-10%%から10%%の範囲で設定してください';
    END IF;

    IF p_margin_rate < 0 OR p_margin_rate > 1 THEN
      RAISE EXCEPTION 'マージン率は0%%から100%%の範囲で設定してください';
    END IF;
  END IF;

  -- ========================================
  -- STEP 2: 個人利益の計算・配布（NFT 1つあたりの利益）
  -- ========================================

  -- NFT 1つあたりの個人利益を計算
  v_personal_profit_per_nft := (1000.0 * p_yield_rate / 100.0) * (1.0 - p_margin_rate) * 0.6;

  -- 既存のデータを削除（再実行時）
  DELETE FROM nft_daily_profit WHERE date = p_date;

  -- 各ユーザーのNFT数に応じて個人利益を配布
  FOR v_user_record IN
    SELECT
      u.user_id,
      u.is_pegasus_exchange,
      u.operation_start_date,
      COUNT(nm.id) as nft_count
    FROM users u
    INNER JOIN nft_master nm ON u.user_id = nm.user_id
    WHERE nm.buyback_date IS NULL
      AND u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= p_date
    GROUP BY u.user_id, u.is_pegasus_exchange, u.operation_start_date
  LOOP
    -- ペガサス交換ユーザーは個人利益なし
    IF v_user_record.is_pegasus_exchange = TRUE THEN
      CONTINUE;
    END IF;

    v_nft_count := v_user_record.nft_count;

    -- NFT数分の個人利益を配布
    FOR i IN 1..v_nft_count LOOP
      INSERT INTO nft_daily_profit (
        user_id,
        date,
        daily_profit,
        phase,
        created_at
      ) VALUES (
        v_user_record.user_id,
        p_date,
        v_personal_profit_per_nft,
        'USDT',
        NOW()
      );
    END LOOP;

    -- available_usdtに加算
    UPDATE affiliate_cycle
    SET
      available_usdt = available_usdt + (v_personal_profit_per_nft * v_nft_count),
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id;

    v_total_users := v_total_users + 1;
    v_total_personal_profit := v_total_personal_profit + (v_personal_profit_per_nft * v_nft_count);
  END LOOP;

  -- ========================================
  -- STEP 3: 紹介報酬の計算・配布（プラス利益時のみ）
  -- ========================================

  -- 既存のデータを削除（再実行時）
  DELETE FROM user_referral_profit WHERE date = p_date;

  -- プラス利益の場合のみ紹介報酬を配布
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

      -- Level 1 紹介報酬
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

          UPDATE affiliate_cycle
          SET
            cum_usdt = cum_usdt + (v_user_profit * v_level1_rate),
            updated_at = NOW()
          WHERE user_id = v_level1_user_id;

          v_total_referral_profit := v_total_referral_profit + (v_user_profit * v_level1_rate);
        END IF;

        -- Level 2 紹介報酬
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
              updated_at = NOW()
            WHERE user_id = v_level2_user_id;

            v_total_referral_profit := v_total_referral_profit + (v_user_profit * v_level2_rate);
          END IF;

          -- Level 3 紹介報酬
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

              UPDATE affiliate_cycle
              SET
                cum_usdt = cum_usdt + (v_user_profit * v_level3_rate),
                updated_at = NOW()
              WHERE user_id = v_referral_user_id;

              v_total_referral_profit := v_total_referral_profit + (v_user_profit * v_level3_rate);
            END IF;
          END IF;
        END IF;
      END IF;
    END LOOP;
  END IF;

  -- ========================================
  -- STEP 4: NFT自動付与処理（cum_usdt >= 2200のユーザー）
  -- ========================================

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
    -- NFTマスターに追加
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

    -- purchasesテーブルに記録
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

    -- affiliate_cycleを更新
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

  -- ========================================
  -- STEP 5: 結果を返す
  -- ========================================

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
      'is_test_mode', p_is_test_mode
    ) as details;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- 修正完了メッセージ
-- ========================================
SELECT '✅✅✅ process_daily_yield_with_cycles 関数の修正が完了しました ✅✅✅' as status;

SELECT '修正内容:' as info;
SELECT '1. STEP 2（個人利益配布）: operation_start_date IS NOT NULL AND operation_start_date <= p_date をチェック' as fix1;
SELECT '2. STEP 3（紹介報酬配布）: 紹介される側と紹介者の両方の operation_start_date をチェック' as fix2;
SELECT '3. STEP 4（NFT自動付与）: operation_start_date をチェック' as fix3;

SELECT '次のステップ: STEP4-FIX-USER-FLAGS.sql を実行してください' as next_step;
