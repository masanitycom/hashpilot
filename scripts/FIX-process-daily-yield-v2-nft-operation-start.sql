-- ========================================
-- 重大バグ修正: NFTごとの運用開始日チェック
-- ========================================
-- 問題: 既存ユーザーが追加購入したNFTが即座に運用開始される
-- 原因: users.operation_start_dateのみチェックしていた
-- 解決: 各NFTのacquired_dateから運用開始日を計算してチェック

-- ========================================
-- STEP 1: nft_masterにoperation_start_dateカラム追加
-- ========================================
ALTER TABLE nft_master
ADD COLUMN IF NOT EXISTS operation_start_date DATE;

COMMENT ON COLUMN nft_master.operation_start_date IS 'このNFTの運用開始日（acquired_dateから計算）';

-- ========================================
-- STEP 2: 既存NFTのoperation_start_dateを設定
-- ========================================
UPDATE nft_master nm
SET operation_start_date = calculate_operation_start_date(nm.acquired_date)
WHERE nm.operation_start_date IS NULL;

-- ========================================
-- STEP 3: NFT承認時にoperation_start_dateを設定するトリガー
-- ========================================
CREATE OR REPLACE FUNCTION set_nft_operation_start_date()
RETURNS TRIGGER AS $$
BEGIN
  -- operation_start_dateがNULLの場合、acquired_dateから計算
  IF NEW.operation_start_date IS NULL AND NEW.acquired_date IS NOT NULL THEN
    NEW.operation_start_date := calculate_operation_start_date(NEW.acquired_date);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_nft_operation_start_date ON nft_master;
CREATE TRIGGER trigger_set_nft_operation_start_date
  BEFORE INSERT OR UPDATE OF acquired_date ON nft_master
  FOR EACH ROW
  EXECUTE FUNCTION set_nft_operation_start_date();

-- ========================================
-- STEP 4: process_daily_yield_v2を修正
-- ========================================
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
  v_referral_record RECORD;
  v_user_profit NUMERIC;
  v_user_nft_count INTEGER;
  v_total_distributed NUMERIC := 0;
  v_total_referral NUMERIC := 0;
  v_total_stock NUMERIC := 0;
  v_referral_count INTEGER := 0;
  v_auto_nft_count INTEGER := 0;
  v_level1_rate NUMERIC := 0.20;
  v_level2_rate NUMERIC := 0.10;
  v_level3_rate NUMERIC := 0.05;
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
      DELETE FROM user_referral_profit WHERE date = p_date;
      DELETE FROM stock_fund WHERE date = p_date;
    END IF;
  END IF;

  -- ★★★ 修正箇所: NFTごとのoperation_start_dateをチェック ★★★
  SELECT COUNT(*)
  INTO v_total_nft_count
  FROM nft_master nm
  JOIN users u ON nm.user_id = u.user_id
  WHERE nm.buyback_date IS NULL
    AND nm.operation_start_date IS NOT NULL
    AND nm.operation_start_date <= p_date  -- ★ NFTの運用開始日をチェック
    AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL);

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
    date,
    total_profit_amount,
    total_nft_count,
    profit_per_nft,
    cumulative_gross_profit,
    fee_rate,
    cumulative_fee,
    cumulative_net_profit,
    daily_pnl,
    distribution_dividend,
    distribution_affiliate,
    distribution_stock,
    is_month_end,
    created_by
  ) VALUES (
    p_date,
    p_total_profit_amount,
    v_total_nft_count,
    v_profit_per_nft,
    v_cumulative_gross,
    v_fee_rate,
    v_cumulative_fee,
    v_cumulative_net,
    v_daily_pnl,
    v_distribution_dividend,
    v_distribution_affiliate,
    v_distribution_stock,
    EXTRACT(DAY FROM (p_date + INTERVAL '1 day')) = 1,
    current_user
  );

  -- ★★★ 修正箇所: 個人利益配布もNFTごとにチェック ★★★
  IF v_distribution_dividend != 0 THEN
    FOR v_user_record IN
      SELECT
        u.user_id,
        u.id as user_uuid,
        COUNT(nm.id) as nft_count
      FROM users u
      JOIN nft_master nm ON nm.user_id = u.user_id
      WHERE nm.buyback_date IS NULL
        AND nm.operation_start_date IS NOT NULL
        AND nm.operation_start_date <= p_date  -- ★ NFTの運用開始日をチェック
        AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
      GROUP BY u.user_id, u.id
    LOOP
      v_user_profit := (v_distribution_dividend / v_total_nft_count) * v_user_record.nft_count;

      -- ★★★ 修正箇所: 運用開始済みのNFTのみに日利を記録 ★★★
      FOR v_nft_record IN
        SELECT id as nft_id
        FROM nft_master
        WHERE user_id = v_user_record.user_id
          AND buyback_date IS NULL
          AND operation_start_date IS NOT NULL
          AND operation_start_date <= p_date  -- ★ NFTの運用開始日をチェック
      LOOP
        INSERT INTO nft_daily_profit (
          nft_id,
          user_id,
          date,
          daily_profit,
          yield_rate,
          user_rate,
          base_amount,
          phase,
          created_at
        ) VALUES (
          v_nft_record.nft_id,
          v_user_record.user_id,
          p_date,
          v_user_profit / v_user_record.nft_count,
          NULL,
          NULL,
          1000,
          'DIVIDEND',
          NOW()
        );
      END LOOP;

      UPDATE affiliate_cycle
      SET
        available_usdt = available_usdt + v_user_profit,
        updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_distributed := v_total_distributed + v_user_profit;
    END LOOP;
  END IF;

  -- 紹介報酬計算（プラスの時のみ）
  IF v_distribution_dividend > 0 THEN
    -- Level 1 紹介報酬
    FOR v_user_record IN
      SELECT DISTINCT u.user_id
      FROM users u
      WHERE u.has_approved_nft = true
        AND u.operation_start_date IS NOT NULL
        AND u.operation_start_date <= p_date
        AND EXISTS (
          SELECT 1 FROM users child
          WHERE child.referrer_user_id = u.user_id
        )
    LOOP
      FOR v_referral_record IN
        SELECT
          child.user_id as child_user_id,
          COALESCE(SUM(ndp.daily_profit), 0) as child_profit
        FROM users child
        LEFT JOIN nft_daily_profit ndp ON ndp.user_id = child.user_id AND ndp.date = p_date
        WHERE child.referrer_user_id = v_user_record.user_id
          AND child.has_approved_nft = true
          AND child.operation_start_date IS NOT NULL
          AND child.operation_start_date <= p_date
        GROUP BY child.user_id
        HAVING COALESCE(SUM(ndp.daily_profit), 0) > 0
      LOOP
        INSERT INTO user_referral_profit (
          user_id,
          date,
          referral_level,
          child_user_id,
          profit_amount
        ) VALUES (
          v_user_record.user_id,
          p_date,
          1,
          v_referral_record.child_user_id,
          v_referral_record.child_profit * v_level1_rate
        );

        UPDATE affiliate_cycle
        SET
          cum_usdt = cum_usdt + (v_referral_record.child_profit * v_level1_rate),
          available_usdt = available_usdt + (v_referral_record.child_profit * v_level1_rate),
          updated_at = NOW()
        WHERE user_id = v_user_record.user_id;

        v_total_referral := v_total_referral + (v_referral_record.child_profit * v_level1_rate);
        v_referral_count := v_referral_count + 1;
      END LOOP;

      -- Level 2 紹介報酬
      FOR v_referral_record IN
        SELECT
          child.user_id as child_user_id,
          COALESCE(SUM(ndp.daily_profit), 0) as child_profit
        FROM users level1
        JOIN users child ON child.referrer_user_id = level1.user_id
        LEFT JOIN nft_daily_profit ndp ON ndp.user_id = child.user_id AND ndp.date = p_date
        WHERE level1.referrer_user_id = v_user_record.user_id
          AND level1.has_approved_nft = true
          AND child.has_approved_nft = true
          AND child.operation_start_date IS NOT NULL
          AND child.operation_start_date <= p_date
        GROUP BY child.user_id
        HAVING COALESCE(SUM(ndp.daily_profit), 0) > 0
      LOOP
        INSERT INTO user_referral_profit (
          user_id,
          date,
          referral_level,
          child_user_id,
          profit_amount
        ) VALUES (
          v_user_record.user_id,
          p_date,
          2,
          v_referral_record.child_user_id,
          v_referral_record.child_profit * v_level2_rate
        );

        UPDATE affiliate_cycle
        SET
          cum_usdt = cum_usdt + (v_referral_record.child_profit * v_level2_rate),
          available_usdt = available_usdt + (v_referral_record.child_profit * v_level2_rate),
          updated_at = NOW()
        WHERE user_id = v_user_record.user_id;

        v_total_referral := v_total_referral + (v_referral_record.child_profit * v_level2_rate);
        v_referral_count := v_referral_count + 1;
      END LOOP;

      -- Level 3 紹介報酬
      FOR v_referral_record IN
        SELECT
          child.user_id as child_user_id,
          COALESCE(SUM(ndp.daily_profit), 0) as child_profit
        FROM users level1
        JOIN users level2 ON level2.referrer_user_id = level1.user_id
        JOIN users child ON child.referrer_user_id = level2.user_id
        LEFT JOIN nft_daily_profit ndp ON ndp.user_id = child.user_id AND ndp.date = p_date
        WHERE level1.referrer_user_id = v_user_record.user_id
          AND level1.has_approved_nft = true
          AND level2.has_approved_nft = true
          AND child.has_approved_nft = true
          AND child.operation_start_date IS NOT NULL
          AND child.operation_start_date <= p_date
        GROUP BY child.user_id
        HAVING COALESCE(SUM(ndp.daily_profit), 0) > 0
      LOOP
        INSERT INTO user_referral_profit (
          user_id,
          date,
          referral_level,
          child_user_id,
          profit_amount
        ) VALUES (
          v_user_record.user_id,
          p_date,
          3,
          v_referral_record.child_user_id,
          v_referral_record.child_profit * v_level3_rate
        );

        UPDATE affiliate_cycle
        SET
          cum_usdt = cum_usdt + (v_referral_record.child_profit * v_level3_rate),
          available_usdt = available_usdt + (v_referral_record.child_profit * v_level3_rate),
          updated_at = NOW()
        WHERE user_id = v_user_record.user_id;

        v_total_referral := v_total_referral + (v_referral_record.child_profit * v_level3_rate);
        v_referral_count := v_referral_count + 1;
      END LOOP;
    END LOOP;
  END IF;

  -- NFT自動付与（サイクル機能）
  FOR v_user_record IN
    SELECT
      u.user_id,
      u.id as user_uuid,
      ac.cum_usdt,
      ac.auto_nft_count
    FROM users u
    JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE ac.cum_usdt >= 2200
  LOOP
    -- ★★★ 修正箇所: 自動NFTにもoperation_start_dateを設定 ★★★
    INSERT INTO nft_master (
      user_id,
      nft_type,
      acquired_date,
      buyback_date,
      operation_start_date  -- ★ 追加（トリガーで自動設定されるが明示的にも）
    ) VALUES (
      v_user_record.user_id,
      'auto',
      p_date,
      NULL,
      calculate_operation_start_date(p_date)  -- ★ 運用開始日を計算
    );

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

    UPDATE affiliate_cycle
    SET
      cum_usdt = cum_usdt - 1100,
      available_usdt = available_usdt + 1100,
      auto_nft_count = auto_nft_count + 1,
      total_nft_count = total_nft_count + 1,
      phase = CASE WHEN (cum_usdt - 1100) >= 1100 THEN 'HOLD' ELSE 'USDT' END,
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id;

    UPDATE users
    SET
      has_approved_nft = true,
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id;

    v_auto_nft_count := v_auto_nft_count + 1;
  END LOOP;

  -- ストック資金配布
  IF v_distribution_stock != 0 THEN
    FOR v_user_record IN
      SELECT
        u.user_id,
        COUNT(nm.id) as nft_count
      FROM users u
      JOIN nft_master nm ON nm.user_id = u.user_id
      WHERE nm.buyback_date IS NULL
        AND nm.operation_start_date IS NOT NULL
        AND nm.operation_start_date <= p_date  -- ★ NFTの運用開始日をチェック
        AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
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

  IF ABS((v_cumulative_net + v_cumulative_fee) - v_cumulative_gross) > 0.01 THEN
    RAISE WARNING '整合性エラー: N_d + F_d != G_d';
  END IF;

  RETURN QUERY SELECT
    'SUCCESS'::TEXT,
    format('日利計算完了: %s', p_date)::TEXT,
    jsonb_build_object(
      'date', p_date,
      'input', jsonb_build_object(
        'total_profit_amount', p_total_profit_amount,
        'total_nft_count', v_total_nft_count,
        'profit_per_nft', v_profit_per_nft
      ),
      'cumulative', jsonb_build_object(
        'G_d', v_cumulative_gross,
        'F_d', v_cumulative_fee,
        'N_d', v_cumulative_net,
        'ΔN_d', v_daily_pnl
      ),
      'distribution', jsonb_build_object(
        'dividend', v_distribution_dividend,
        'affiliate', v_distribution_affiliate,
        'stock', v_distribution_stock,
        'total_distributed', v_total_distributed,
        'total_referral', v_total_referral,
        'total_stock', v_total_stock,
        'referral_count', v_referral_count,
        'auto_nft_count', v_auto_nft_count
      )
    );

EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT
      'ERROR'::TEXT,
      format('エラー: %s', SQLERRM)::TEXT,
      jsonb_build_object('error_detail', SQLERRM);
END;
$$;

-- ========================================
-- 確認クエリ
-- ========================================
SELECT '=== STEP 1-4 完了 ===' as status;

-- 既存NFTのoperation_start_date設定状況
SELECT
  COUNT(*) as total_nfts,
  COUNT(operation_start_date) as with_operation_start_date,
  COUNT(*) - COUNT(operation_start_date) as without_operation_start_date
FROM nft_master
WHERE buyback_date IS NULL;

-- 1月以降に運用開始を待つNFT（追加購入分など）
SELECT '=== 運用開始待ちのNFT ===' as section;
SELECT
  nm.user_id,
  nm.acquired_date as 購入日,
  nm.operation_start_date as 運用開始日,
  nm.nft_type as タイプ,
  u.email
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date IS NULL
  AND nm.operation_start_date > CURRENT_DATE
ORDER BY nm.operation_start_date, nm.user_id;
