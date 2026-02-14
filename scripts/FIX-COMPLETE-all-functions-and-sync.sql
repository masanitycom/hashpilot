-- ========================================
-- 全RPC関数の完全修正 + cum_usdt同期
-- ========================================
-- 作成日: 2026-02-14
--
-- 修正内容:
--   PART 1: process_daily_yield_v2 — cum_usdt/NFTロジック削除
--   PART 2: process_monthly_referral_reward — $2200サイクル+NFT付与追加
--   PART 3: process_monthly_withdrawals — 紹介報酬計算を統一式に修正
--   PART 4: cum_usdtの全ユーザー一括同期
--
-- 実行順序: PART 1 → 2 → 3 → 4（順番に実行してください）
-- ========================================

-- ########################################
-- PART 1: process_daily_yield_v2 修正
-- ########################################
-- 変更点:
--   - cum_usdt更新（stock 10%加算）を削除
--   - NFT自動付与ロジックを削除
--   - 日次処理は個人利益（60%配当）のみに特化
-- ########################################

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
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_nft_count INTEGER;
  v_profit_per_nft NUMERIC;
  v_dividend_per_nft NUMERIC;
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
BEGIN
  -- ========================================
  -- STEP 1: 入力検証
  -- ========================================
  IF p_date IS NULL THEN
    RETURN QUERY SELECT 'ERROR'::TEXT, 'Date is required'::TEXT, NULL::JSONB;
    RETURN;
  END IF;

  IF p_total_profit_amount IS NULL THEN
    RETURN QUERY SELECT 'ERROR'::TEXT, 'Profit amount is required'::TEXT, NULL::JSONB;
    RETURN;
  END IF;

  IF EXISTS (SELECT 1 FROM daily_yield_log_v2 WHERE date = p_date) THEN
    IF NOT p_is_test_mode THEN
      RETURN QUERY SELECT 'ERROR'::TEXT, 'Already set for this date'::TEXT, NULL::JSONB;
      RETURN;
    END IF;
  END IF;

  -- ========================================
  -- STEP 2: 対象NFT数を計算
  -- ========================================
  SELECT COUNT(*)
  INTO v_total_nft_count
  FROM nft_master nm
  INNER JOIN users u ON nm.user_id = u.user_id
  WHERE nm.buyback_date IS NULL
    AND u.has_approved_nft = true
    AND nm.operation_start_date IS NOT NULL
    AND nm.operation_start_date <= p_date
    AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
    AND NOT EXISTS (
      SELECT 1 FROM buyback_requests br
      WHERE br.user_id = nm.user_id AND br.status = 'pending'
    );

  IF v_total_nft_count = 0 THEN
    RETURN QUERY SELECT 'ERROR'::TEXT, 'No active NFTs'::TEXT, NULL::JSONB;
    RETURN;
  END IF;

  -- ========================================
  -- STEP 3: 利益計算
  -- ========================================
  v_profit_per_nft := p_total_profit_amount / v_total_nft_count;

  SELECT
    COALESCE(cumulative_gross_profit, 0),
    COALESCE(cumulative_net_profit, 0)
  INTO v_prev_cumulative_gross, v_prev_cumulative_net
  FROM daily_yield_log_v2
  WHERE date < p_date
  ORDER BY date DESC
  LIMIT 1;

  v_cumulative_gross := v_prev_cumulative_gross + p_total_profit_amount;
  v_cumulative_fee := v_cumulative_gross * v_fee_rate;
  v_cumulative_net := v_cumulative_gross - v_cumulative_fee;
  v_daily_pnl := v_cumulative_net - v_prev_cumulative_net;

  v_distribution_dividend := v_daily_pnl * 0.60;
  v_distribution_affiliate := v_daily_pnl * 0.30;
  v_distribution_stock := v_daily_pnl * 0.10;

  v_dividend_per_nft := v_distribution_dividend / v_total_nft_count;

  -- ========================================
  -- STEP 4: daily_yield_log_v2に記録
  -- ========================================
  IF p_is_test_mode THEN
    DELETE FROM daily_yield_log_v2 WHERE date = p_date;
  END IF;

  INSERT INTO daily_yield_log_v2 (
    date, total_profit_amount, total_nft_count, profit_per_nft,
    cumulative_gross_profit, cumulative_fee, cumulative_net_profit,
    daily_pnl, distribution_dividend, distribution_affiliate,
    distribution_stock, fee_rate, created_at
  ) VALUES (
    p_date, p_total_profit_amount, v_total_nft_count,
    v_profit_per_nft,
    v_cumulative_gross, v_cumulative_fee, v_cumulative_net,
    v_daily_pnl, v_distribution_dividend, v_distribution_affiliate,
    v_distribution_stock, v_fee_rate, NOW()
  );

  -- ========================================
  -- STEP 5: 個人利益配布（60%配当）
  -- ★ これが日次処理の唯一の配布処理
  -- ★ cum_usdt更新やNFT自動付与は月末処理で行う
  -- ========================================
  IF v_distribution_dividend != 0 THEN
    IF p_is_test_mode THEN
      DELETE FROM nft_daily_profit WHERE date = p_date;
    END IF;

    FOR v_user_record IN
      SELECT u.user_id, COUNT(nm.id) as nft_count
      FROM users u
      INNER JOIN nft_master nm ON u.user_id = nm.user_id
      WHERE nm.buyback_date IS NULL
        AND u.has_approved_nft = true
        AND nm.operation_start_date IS NOT NULL
        AND nm.operation_start_date <= p_date
        AND (u.is_pegasus_exchange = false OR u.is_pegasus_exchange IS NULL)
        AND NOT EXISTS (
          SELECT 1 FROM buyback_requests br
          WHERE br.user_id = u.user_id AND br.status = 'pending'
        )
      GROUP BY u.user_id
    LOOP
      v_user_profit := v_dividend_per_nft * v_user_record.nft_count;

      -- NFTごとにレコードを挿入
      FOR v_nft_record IN
        SELECT nm.id as nft_id FROM nft_master nm
        WHERE nm.user_id = v_user_record.user_id
          AND nm.buyback_date IS NULL
          AND nm.operation_start_date IS NOT NULL
          AND nm.operation_start_date <= p_date
      LOOP
        INSERT INTO nft_daily_profit (
          nft_id, user_id, date, daily_profit, yield_rate, user_rate,
          base_amount, phase, created_at
        ) VALUES (
          v_nft_record.nft_id, v_user_record.user_id, p_date,
          v_user_profit / v_user_record.nft_count, NULL, NULL, 1000, 'DIVIDEND', NOW()
        );
      END LOOP;

      -- available_usdtに個人利益を加算
      UPDATE affiliate_cycle
      SET available_usdt = available_usdt + v_user_profit, updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_distributed := v_total_distributed + v_user_profit;
    END LOOP;
  END IF;

  -- ★★★ 削除されたコード ★★★
  -- 以前ここにあったcum_usdt更新（stock 10%加算）とNFT自動付与ロジックは削除
  -- これらは月末処理（process_monthly_referral_reward）で行う
  -- ★★★★★★★★★★★★★★★

  -- ========================================
  -- STEP 6: 結果を返す
  -- ========================================
  RETURN QUERY SELECT
    'SUCCESS'::TEXT,
    format('NFT: %s, Dividend/NFT: $%s, Total: $%s',
      v_total_nft_count,
      ROUND(v_dividend_per_nft::NUMERIC, 4)::TEXT,
      ROUND(v_total_distributed::NUMERIC, 2)::TEXT
    )::TEXT,
    jsonb_build_object(
      'date', p_date,
      'total_nft_count', v_total_nft_count,
      'raw_profit_per_nft', ROUND(v_profit_per_nft::NUMERIC, 4),
      'dividend_per_nft', ROUND(v_dividend_per_nft::NUMERIC, 4),
      'distributed', ROUND(v_total_distributed::NUMERIC, 2)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION process_daily_yield_v2(DATE, NUMERIC, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION process_daily_yield_v2(DATE, NUMERIC, BOOLEAN) TO anon;


-- ########################################
-- PART 2: process_monthly_referral_reward 修正
-- ########################################
-- 変更点:
--   1. cum_usdtのみ更新（available_usdtは月末にまとめて計算）
--   2. NFT自動付与: cum_usdt >= 2200 で$2200減算（WHILEループで複数対応）
--   3. 月末に正確な払出額を計算（スナップショット方式）
--   4. 解約ユーザーの紹介報酬を会社アカウント（7A9637）にリダイレクト
--   5. phase計算: cum_usdt < 1100 → USDT, それ以外 → HOLD
-- ########################################

DROP FUNCTION IF EXISTS process_monthly_referral_reward(INTEGER, INTEGER, BOOLEAN);

CREATE OR REPLACE FUNCTION process_monthly_referral_reward(
  p_year INTEGER,
  p_month INTEGER,
  p_overwrite BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(
  status TEXT,
  message TEXT,
  details JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
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
  v_company_user_id TEXT := '7A9637';  -- 会社アカウント
  v_reward_recipient TEXT;  -- 報酬の受取先（通常は紹介者、解約済みなら会社）
  v_is_cancelled BOOLEAN;
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
  v_end_date := (v_start_date + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
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
      DELETE FROM monthly_referral_profit WHERE year_month = v_year_month;
    END IF;
  END IF;

  -- ========================================
  -- STEP 2: スナップショット保存
  -- 月初のcum_usdtとauto_nft_countを記録
  -- 月末に正確な払出額を計算するために必要
  -- ========================================
  DROP TABLE IF EXISTS temp_cycle_snapshot;
  CREATE TEMP TABLE temp_cycle_snapshot AS
  SELECT
    user_id,
    cum_usdt,
    auto_nft_count,
    available_usdt
  FROM affiliate_cycle;

  -- ========================================
  -- STEP 3: 各ユーザーの月次日利合計を計算
  -- プラス・マイナス両方含む、月末合計がプラスの場合のみ対象
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
  -- STEP 4: Level 1 紹介報酬計算
  -- ★ cum_usdtのみ更新（available_usdtは更新しない）
  -- ★ 解約ユーザーの報酬は会社アカウントにリダイレクト
  -- ========================================
  FOR v_user_record IN
    SELECT DISTINCT u.user_id
    FROM users u
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= v_end_date
      AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
      AND EXISTS (
        SELECT 1 FROM users child
        WHERE child.referrer_user_id = u.user_id
      )
  LOOP
    -- 解約チェック: 全NFTが買取済みかどうか
    SELECT bool_and(nm.buyback_date IS NOT NULL AND nm.buyback_date <= v_end_date)
    INTO v_is_cancelled
    FROM nft_master nm
    WHERE nm.user_id = v_user_record.user_id;

    -- 解約済みなら会社アカウントに報酬をリダイレクト
    v_reward_recipient := CASE WHEN COALESCE(v_is_cancelled, FALSE) THEN v_company_user_id ELSE v_user_record.user_id END;

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
        v_reward_recipient, v_year_month, 1, v_child_record.child_user_id,
        v_child_record.child_monthly_profit * v_level1_rate,
        v_end_date, NOW()
      );

      -- cum_usdtのみ更新（available_usdtは月末にまとめて計算）
      UPDATE affiliate_cycle
      SET cum_usdt = cum_usdt + (v_child_record.child_monthly_profit * v_level1_rate),
          updated_at = NOW()
      WHERE user_id = v_reward_recipient;

      v_total_referral := v_total_referral + (v_child_record.child_monthly_profit * v_level1_rate);
      v_total_records := v_total_records + 1;
    END LOOP;
  END LOOP;

  -- ========================================
  -- STEP 5: Level 2 紹介報酬計算
  -- ========================================
  FOR v_user_record IN
    SELECT DISTINCT u.user_id
    FROM users u
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= v_end_date
      AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
  LOOP
    -- 解約チェック
    SELECT bool_and(nm.buyback_date IS NOT NULL AND nm.buyback_date <= v_end_date)
    INTO v_is_cancelled
    FROM nft_master nm
    WHERE nm.user_id = v_user_record.user_id;

    v_reward_recipient := CASE WHEN COALESCE(v_is_cancelled, FALSE) THEN v_company_user_id ELSE v_user_record.user_id END;

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
        v_reward_recipient, v_year_month, 2, v_child_record.child_user_id,
        v_child_record.child_monthly_profit * v_level2_rate,
        v_end_date, NOW()
      );

      UPDATE affiliate_cycle
      SET cum_usdt = cum_usdt + (v_child_record.child_monthly_profit * v_level2_rate),
          updated_at = NOW()
      WHERE user_id = v_reward_recipient;

      v_total_referral := v_total_referral + (v_child_record.child_monthly_profit * v_level2_rate);
      v_total_records := v_total_records + 1;
    END LOOP;
  END LOOP;

  -- ========================================
  -- STEP 6: Level 3 紹介報酬計算
  -- ========================================
  FOR v_user_record IN
    SELECT DISTINCT u.user_id
    FROM users u
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= v_end_date
      AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
  LOOP
    -- 解約チェック
    SELECT bool_and(nm.buyback_date IS NOT NULL AND nm.buyback_date <= v_end_date)
    INTO v_is_cancelled
    FROM nft_master nm
    WHERE nm.user_id = v_user_record.user_id;

    v_reward_recipient := CASE WHEN COALESCE(v_is_cancelled, FALSE) THEN v_company_user_id ELSE v_user_record.user_id END;

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
        v_reward_recipient, v_year_month, 3, v_child_record.child_user_id,
        v_child_record.child_monthly_profit * v_level3_rate,
        v_end_date, NOW()
      );

      UPDATE affiliate_cycle
      SET cum_usdt = cum_usdt + (v_child_record.child_monthly_profit * v_level3_rate),
          updated_at = NOW()
      WHERE user_id = v_reward_recipient;

      v_total_referral := v_total_referral + (v_child_record.child_monthly_profit * v_level3_rate);
      v_total_records := v_total_records + 1;
    END LOOP;
  END LOOP;

  -- ========================================
  -- STEP 7: NFT自動付与（cum_usdt >= 2200）
  -- ★ $2,200を減算（$1,100ではない）
  -- ★ available_usdtはSTEP 8で正確に計算
  -- ★ WHILEループで複数NFT付与に対応
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
    v_nft_to_grant := FLOOR(v_user_record.cum_usdt / 2200)::INTEGER;

    FOR v_i IN 1..v_nft_to_grant LOOP
      -- 次のnft_sequenceを計算
      SELECT COALESCE(MAX(nft_sequence), 0) + 1
      INTO v_next_sequence
      FROM nft_master
      WHERE user_id = v_user_record.user_id;

      -- NFT作成
      INSERT INTO nft_master (
        user_id, nft_sequence, nft_type, nft_value,
        acquired_date, buyback_date, operation_start_date
      ) VALUES (
        v_user_record.user_id, v_next_sequence, 'auto', 1000,
        v_end_date, NULL, calculate_operation_start_date(v_end_date)
      );

      -- purchasesに記録
      INSERT INTO purchases (
        user_id, nft_quantity, amount_usd, payment_status,
        admin_approved, admin_approved_at,
        cycle_number_at_purchase, is_auto_purchase
      ) VALUES (
        v_user_record.user_id, 1, 1100, 'completed',
        true, NOW(),
        v_user_record.auto_nft_count + v_i, true
      );

      v_auto_nft_count := v_auto_nft_count + 1;
    END LOOP;

    -- affiliate_cycleを更新
    -- cum_usdt - (NFT数 × 2200)
    -- available_usdtはSTEP 8で正確に計算するのでここでは触らない
    UPDATE affiliate_cycle
    SET
      cum_usdt = cum_usdt - (v_nft_to_grant * 2200),
      auto_nft_count = auto_nft_count + v_nft_to_grant,
      total_nft_count = total_nft_count + v_nft_to_grant,
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

  -- ========================================
  -- STEP 8: 正確な払出額を計算してavailable_usdtに加算
  -- ★★★ これが最重要な修正ポイント ★★★
  --
  -- 計算式:
  -- total_payout_before = (snapshot.auto_nft_count × 1100) + LEAST(snapshot.cum_usdt, 1100)
  -- total_payout_after  = (current.auto_nft_count × 1100) + LEAST(current.cum_usdt, 1100)
  -- monthly_payout = total_payout_after - total_payout_before
  --
  -- この計算式により、USDTフェーズでは紹介報酬がavailable_usdtに加算され、
  -- HOLDフェーズでは加算されない（正確に$1,100まで）
  -- NFT購入時は自動的に$1,100がavailable_usdtに加算される
  -- ========================================
  UPDATE affiliate_cycle ac
  SET
    available_usdt = ac.available_usdt + GREATEST(0,
      (ac.auto_nft_count * 1100 + LEAST(ac.cum_usdt, 1100))
      - (s.auto_nft_count * 1100 + LEAST(s.cum_usdt, 1100))
    ),
    phase = CASE
      WHEN ac.cum_usdt < 1100 THEN 'USDT'
      ELSE 'HOLD'
    END,
    updated_at = NOW()
  FROM temp_cycle_snapshot s
  WHERE ac.user_id = s.user_id;

  -- ========================================
  -- STEP 9: 集計
  -- ========================================
  SELECT COUNT(DISTINCT user_id)
  INTO v_total_users
  FROM monthly_referral_profit
  WHERE year_month = v_year_month;

  DROP TABLE IF EXISTS temp_monthly_profit;
  DROP TABLE IF EXISTS temp_cycle_snapshot;

  -- ========================================
  -- STEP 10: 結果を返す
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
    DROP TABLE IF EXISTS temp_cycle_snapshot;
    RETURN QUERY SELECT
      'ERROR'::TEXT,
      format('エラー: %s', SQLERRM)::TEXT,
      jsonb_build_object('error_detail', SQLERRM);
END;
$$;

GRANT EXECUTE ON FUNCTION process_monthly_referral_reward(INTEGER, INTEGER, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION process_monthly_referral_reward(INTEGER, INTEGER, BOOLEAN) TO anon;


-- ########################################
-- PART 3: process_monthly_withdrawals 修正
-- ########################################
-- 変更点:
--   - referral_amountの計算を統一式に変更
--   - user_referral_profit_monthly → monthly_referral_profit に変更
--   - 統一式: (auto_nft_count × 1100 + LEAST(cum_usdt, 1100)) - withdrawn_referral_usdt
-- ########################################

DROP FUNCTION IF EXISTS process_monthly_withdrawals(DATE);

CREATE OR REPLACE FUNCTION process_monthly_withdrawals(
    p_target_month DATE DEFAULT NULL
)
RETURNS TABLE(
    processed_count INTEGER,
    total_amount NUMERIC,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_processed_count INTEGER := 0;
    v_total_amount NUMERIC := 0;
    v_target_month DATE;
    v_today DATE;
    v_last_day DATE;
    v_year INTEGER;
    v_month INTEGER;
    v_year_month TEXT;
    v_user_record RECORD;
    v_personal_amount NUMERIC;
    v_referral_amount NUMERIC;
    v_total_payout_ever NUMERIC;
BEGIN
    v_today := (NOW() AT TIME ZONE 'Asia/Tokyo')::DATE;

    IF p_target_month IS NULL THEN
        v_target_month := DATE_TRUNC('month', v_today)::DATE;
    ELSE
        v_target_month := DATE_TRUNC('month', p_target_month)::DATE;
    END IF;

    v_last_day := (DATE_TRUNC('month', v_target_month) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

    IF v_today != v_last_day AND p_target_month IS NULL THEN
        RAISE NOTICE '⚠️ 本日（%）は月末（%）ではありません。手動実行として処理を継続します。', v_today, v_last_day;
    END IF;

    v_year := EXTRACT(YEAR FROM v_target_month);
    v_month := EXTRACT(MONTH FROM v_target_month);
    v_year_month := format('%s-%s', v_year, LPAD(v_month::TEXT, 2, '0'));

    FOR v_user_record IN
        SELECT
            ac.user_id,
            u.email,
            ac.available_usdt,
            ac.cum_usdt,
            ac.auto_nft_count,
            ac.phase,
            COALESCE(ac.withdrawn_referral_usdt, 0) as withdrawn_referral_usdt,
            COALESCE(u.coinw_uid, '') as coinw_uid,
            COALESCE(u.nft_receive_address, '') as nft_receive_address,
            u.is_pegasus_exchange,
            u.pegasus_withdrawal_unlock_date
        FROM affiliate_cycle ac
        INNER JOIN users u ON ac.user_id = u.user_id
        WHERE ac.available_usdt >= 10
          AND NOT (
              COALESCE(u.is_pegasus_exchange, FALSE) = TRUE
              AND (
                  u.pegasus_withdrawal_unlock_date IS NULL
                  OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
              )
          )
          AND NOT EXISTS (
              SELECT 1
              FROM monthly_withdrawals mw
              WHERE mw.user_id = ac.user_id
                AND mw.withdrawal_month = v_target_month
          )
    LOOP
        -- 個人利益を計算（nft_daily_profitから当月分）
        SELECT COALESCE(SUM(daily_profit), 0)
        INTO v_personal_amount
        FROM nft_daily_profit
        WHERE user_id = v_user_record.user_id
          AND date >= v_target_month
          AND date < (v_target_month + INTERVAL '1 month');

        -- ★ 紹介報酬を統一計算式で計算
        -- total_payout_ever = (auto_nft_count × 1100) + LEAST(cum_usdt, 1100)
        -- withdrawable_referral = total_payout_ever - withdrawn_referral_usdt
        v_total_payout_ever := (v_user_record.auto_nft_count * 1100) + LEAST(GREATEST(v_user_record.cum_usdt, 0), 1100);
        v_referral_amount := GREATEST(0, v_total_payout_ever - v_user_record.withdrawn_referral_usdt);

        -- 小数点第二位で丸め
        v_personal_amount := ROUND(v_personal_amount::NUMERIC, 2);
        v_referral_amount := ROUND(v_referral_amount::NUMERIC, 2);

        DECLARE
            v_withdrawal_method TEXT;
            v_withdrawal_address TEXT;
            v_initial_status TEXT;
        BEGIN
            IF v_user_record.coinw_uid != '' THEN
                v_withdrawal_method := 'coinw';
                v_withdrawal_address := v_user_record.coinw_uid;
                v_initial_status := 'on_hold';
            ELSIF v_user_record.nft_receive_address != '' THEN
                v_withdrawal_method := 'bep20';
                v_withdrawal_address := v_user_record.nft_receive_address;
                v_initial_status := 'on_hold';
            ELSE
                v_withdrawal_method := NULL;
                v_withdrawal_address := NULL;
                v_initial_status := 'on_hold';
            END IF;

            INSERT INTO monthly_withdrawals (
                user_id, email, withdrawal_month,
                total_amount, personal_amount, referral_amount,
                withdrawal_method, withdrawal_address,
                status, task_completed,
                created_at, updated_at
            )
            VALUES (
                v_user_record.user_id, v_user_record.email, v_target_month,
                v_personal_amount + v_referral_amount,
                v_personal_amount, v_referral_amount,
                v_withdrawal_method, v_withdrawal_address,
                v_initial_status, false,
                NOW(), NOW()
            );

            INSERT INTO monthly_reward_tasks (
                user_id, year, month,
                is_completed, questions_answered,
                created_at, updated_at
            )
            VALUES (
                v_user_record.user_id, v_year, v_month,
                false, 0, NOW(), NOW()
            )
            ON CONFLICT (user_id, year, month) DO NOTHING;

            v_processed_count := v_processed_count + 1;
            v_total_amount := v_total_amount + (v_personal_amount + v_referral_amount);
        END;
    END LOOP;

    -- ログ記録
    BEGIN
        INSERT INTO system_logs (
            log_type, message, details, created_at
        )
        VALUES (
            'monthly_withdrawal',
            FORMAT('月末出金処理完了: %s年%s月 - 出金申請%s件作成', v_year, v_month, v_processed_count),
            jsonb_build_object(
                'year', v_year,
                'month', v_month,
                'withdrawal_count', v_processed_count,
                'withdrawal_total', v_total_amount,
                'process_date', v_today,
                'target_month', v_target_month
            ),
            NOW()
        );
    EXCEPTION WHEN undefined_table THEN
        NULL;
    END;

    RETURN QUERY
    SELECT
        v_processed_count,
        v_total_amount,
        CASE
            WHEN v_processed_count = 0 THEN
                FORMAT('月末出金処理が完了しました。%s年%s月分 - 新規出金申請: 0件', v_year, v_month)
            ELSE
                FORMAT('月末出金処理が完了しました。%s年%s月分 - 出金申請: %s件（総額: $%s）', v_year, v_month, v_processed_count, v_total_amount::TEXT)
        END;
END;
$$;

GRANT EXECUTE ON FUNCTION process_monthly_withdrawals(DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION process_monthly_withdrawals(DATE) TO anon;


-- ########################################
-- PART 4: cum_usdtの全ユーザー一括同期
-- ########################################
-- 変更点:
--   - cum_usdt = monthly_referral_profitの合計 - (auto_nft_count × 2200)
--   - phase = cum_usdt < 1100 → USDT, それ以外 → HOLD
-- ########################################

SELECT '=== PART 4: cum_usdt同期 ===' as section;

-- 同期前の状態を確認
SELECT '=== 同期前: 不整合があるユーザー ===' as check_section;

SELECT
  ac.user_id,
  ac.cum_usdt as "現在cum_usdt",
  ac.auto_nft_count,
  ac.phase as "現在phase",
  COALESCE(mrp.total_referral, 0) as "紹介報酬累計",
  GREATEST(0, COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200)) as "正しいcum_usdt",
  CASE
    WHEN GREATEST(0, COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200)) < 1100 THEN 'USDT'
    ELSE 'HOLD'
  END as "正しいphase"
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ABS(
  ac.cum_usdt - GREATEST(0, COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200))
) > 0.01
ORDER BY ABS(ac.cum_usdt - GREATEST(0, COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200))) DESC;

-- cum_usdtを同期
UPDATE affiliate_cycle ac
SET
  cum_usdt = GREATEST(0, COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200)),
  phase = CASE
    WHEN GREATEST(0, COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200)) < 1100 THEN 'USDT'
    ELSE 'HOLD'
  END,
  updated_at = NOW()
FROM (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp
WHERE ac.user_id = mrp.user_id;

-- 紹介報酬がないユーザーのcum_usdtを0にリセット
UPDATE affiliate_cycle ac
SET
  cum_usdt = 0,
  phase = 'USDT',
  updated_at = NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM monthly_referral_profit mrp
  WHERE mrp.user_id = ac.user_id
)
AND ac.cum_usdt != 0;

-- 同期後の確認
SELECT '=== 同期後: 不整合チェック ===' as verify_section;

SELECT
  ac.user_id,
  ac.cum_usdt,
  ac.auto_nft_count,
  ac.phase,
  COALESCE(mrp.total_referral, 0) as total_referral,
  GREATEST(0, COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200)) as expected_cum_usdt,
  ABS(ac.cum_usdt - GREATEST(0, COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200))) as difference
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ABS(
  ac.cum_usdt - GREATEST(0, COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200))
) > 0.01;

SELECT '=== 完了: 全PART実行済み ===' as done;
