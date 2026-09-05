-- ============================================================
-- process_daily_yield_v2 修正: 買取申請の判定に日付条件を追加
--
-- 問題:
--   買取判定が status='pending' の存在だけを見ており、日付を見ていない。
--   日利は「その日の分を翌日に入力」する運用のため、申請が入力より先に
--   届くと申請日以前の日利まで配布対象から外れていた。
--   → 買取申請中46名で計 $92.77 の取りこぼしが発生（2026-09-05に補填済み）
--
-- 仕様（docs/TODO.md 2026-02-07確定）: 買取申請の翌日から日利停止
--   → 「日利の日付 <= 申請日(JST)」までは配布する
--
-- 変更箇所は2箇所のみ（NFT総数カウント / ユーザー別集計）。
-- それ以外は 2026-09-05 時点のデプロイ済み定義と完全に同一。
--   ・SECURITY DEFINER と SET search_path TO 'public' を維持
--   ・CREATE OR REPLACE のため既存の権限(GRANT)はそのまま引き継がれる
--
-- 変更内容:
--   AND NOT EXISTS (
--     SELECT 1 FROM buyback_requests br
--     WHERE br.user_id = ... AND br.status = 'pending'
-- +     AND (COALESCE(br.request_date, br.created_at) AT TIME ZONE 'Asia/Tokyo')::date < p_date
--   )
--
--   request_date が NULL の場合は created_at で代替する。
--   （NULLのまま比較すると条件が NULL になり、除外されず配布されてしまうため）
--
-- 実行日: 2026-09-05
-- ============================================================

CREATE OR REPLACE FUNCTION public.process_daily_yield_v2(
  p_date date,
  p_total_profit_amount numeric,
  p_is_test_mode boolean DEFAULT false
)
RETURNS TABLE(status text, message text, details jsonb)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
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

  -- ▼▼▼ 修正箇所 1/2: NFT総数カウント ▼▼▼
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
      WHERE br.user_id = nm.user_id
        AND br.status = 'pending'
        -- 買取申請の翌日から停止（申請日当日までは配布する）
        AND (COALESCE(br.request_date, br.created_at) AT TIME ZONE 'Asia/Tokyo')::date < p_date
    );
  -- ▲▲▲ 修正箇所 1/2 ここまで ▲▲▲

  IF v_total_nft_count = 0 THEN
    RETURN QUERY SELECT 'ERROR'::TEXT, 'No active NFTs'::TEXT, NULL::JSONB;
    RETURN;
  END IF;

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

  IF v_distribution_dividend != 0 THEN
    IF p_is_test_mode THEN
      DELETE FROM nft_daily_profit WHERE date = p_date;
    END IF;

    -- ▼▼▼ 修正箇所 2/2: ユーザー別集計 ▼▼▼
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
          WHERE br.user_id = u.user_id
            AND br.status = 'pending'
            -- 買取申請の翌日から停止（申請日当日までは配布する）
            AND (COALESCE(br.request_date, br.created_at) AT TIME ZONE 'Asia/Tokyo')::date < p_date
        )
      GROUP BY u.user_id
    LOOP
    -- ▲▲▲ 修正箇所 2/2 ここまで ▲▲▲
      v_user_profit := v_dividend_per_nft * v_user_record.nft_count;

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

      UPDATE affiliate_cycle
      SET available_usdt = available_usdt + v_user_profit, updated_at = NOW()
      WHERE user_id = v_user_record.user_id;

      v_total_distributed := v_total_distributed + v_user_profit;
    END LOOP;
  END IF;

  -- 結果を返す（管理画面が期待するネスト構造を含む）
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
      'distributed', ROUND(v_total_distributed::NUMERIC, 2),
      'input', jsonb_build_object(
        'total_nft_count', v_total_nft_count,
        'profit_per_nft', ROUND(v_profit_per_nft::NUMERIC, 4)
      ),
      'distribution', jsonb_build_object(
        'total_distributed', ROUND(v_total_distributed::NUMERIC, 2),
        'auto_nft_count', 0
      )
    );
END;
$function$;


-- ============================================================
-- 検証
-- ============================================================

-- 1) 日付条件が2箇所とも入ったか（2 が返れば正しい）
SELECT (
  length(pg_get_functiondef(p.oid))
  - length(replace(pg_get_functiondef(p.oid), 'Asia/Tokyo', ''))
) / length('Asia/Tokyo') AS 日付条件の数
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname = 'process_daily_yield_v2' AND n.nspname = 'public';

-- 2) SECURITY DEFINER と search_path が維持されているか
SELECT p.proname, p.prosecdef AS security_definer, p.proconfig
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE p.proname = 'process_daily_yield_v2' AND n.nspname = 'public';

-- 3) 権限が残っているか（authenticated 等が見えること）
SELECT grantee, privilege_type
FROM information_schema.routine_privileges
WHERE routine_name = 'process_daily_yield_v2';

-- 4) 買取申請中ユーザーの「申請日当日」が配布対象に含まれるかの事前確認
--    ※ 実際の効果は次回の日利入力時に現れる
SELECT
  br.user_id,
  (COALESCE(br.request_date, br.created_at) AT TIME ZONE 'Asia/Tokyo')::date AS 申請日,
  '申請日の翌日から停止' AS 動作
FROM buyback_requests br
WHERE br.status = 'pending'
ORDER BY 2 DESC
LIMIT 10;
