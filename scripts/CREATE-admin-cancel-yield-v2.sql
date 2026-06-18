-- ============================================================
-- V2日利の安全な削除関数（残高も正しく戻す）
-- ============================================================
-- 【背景】
--   日利設定画面の「削除」ボタンが旧V1テーブルしか消せず、
--   V2の日利を削除できなかった + available_usdt を戻していなかった。
--   この関数は process_daily_yield_v2 が行った配布を正確に巻き戻す。
--
-- 【巻き戻す内容】
--   1. available_usdt … その日 nft_daily_profit で各ユーザーに加算した分を減算
--      （記録された実配布額そのものなので常に正確）
--   2. cum_usdt … プラス日のストック分（profit_per_nft × 保有NFT数 × 10%）を減算
--      ※ process_daily_yield_v2 のSTEP3と同じロジックで再計算
--   3. nft_daily_profit / daily_yield_log_v2 の該当日レコードを削除
--
-- 【安全ガード】
--   その日に自動NFT付与（nft_master.nft_type='auto'）が発生している場合は
--   巻き戻しが複雑になるため自動削除を中止し、手動対応を促す。
--
-- 【想定用途】
--   入力直後〜数日内の誤設定の取り消し（NFT構成が当時と大きく変わらない前提）。
-- ============================================================

CREATE OR REPLACE FUNCTION admin_cancel_yield_v2(p_date DATE)
RETURNS TABLE(success BOOLEAN, message TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_log RECORD;
  v_auto_count INTEGER;
  v_users_reverted INTEGER := 0;
  v_total_reverted NUMERIC := 0;
BEGIN
  -- 対象日のログを取得
  SELECT * INTO v_log FROM daily_yield_log_v2 WHERE date = p_date;
  IF NOT FOUND THEN
    RETURN QUERY SELECT FALSE, format('%s の日利データが見つかりません', p_date::TEXT);
    RETURN;
  END IF;

  -- 安全ガード：自動NFT付与が発生した日は自動削除しない
  SELECT COUNT(*) INTO v_auto_count
  FROM nft_master
  WHERE acquired_date = p_date AND nft_type = 'auto';

  IF v_auto_count > 0 THEN
    RETURN QUERY SELECT FALSE,
      format('%s は自動NFT付与が%s件発生しているため自動削除できません。手動対応が必要です。', p_date::TEXT, v_auto_count);
    RETURN;
  END IF;

  -- 1) available_usdt を戻す（実際に配布した個人利益分 = nft_daily_profit 合計）
  WITH per_user AS (
    SELECT user_id, SUM(daily_profit) AS total
    FROM nft_daily_profit
    WHERE date = p_date
    GROUP BY user_id
  ), upd AS (
    UPDATE affiliate_cycle ac
    SET available_usdt = ac.available_usdt - pu.total,
        updated_at = NOW()
    FROM per_user pu
    WHERE ac.user_id = pu.user_id
    RETURNING pu.total
  )
  SELECT COUNT(*), COALESCE(SUM(total), 0) INTO v_users_reverted, v_total_reverted FROM upd;

  -- 2) cum_usdt を戻す（プラス日のストック分のみ。STEP3と同じ計算）
  IF COALESCE(v_log.distribution_stock, 0) > 0 THEN
    UPDATE affiliate_cycle ac
    SET cum_usdt = ac.cum_usdt - (v_log.profit_per_nft * cnt.n * 0.10),
        updated_at = NOW()
    FROM (
      SELECT nm.user_id, COUNT(*) AS n
      FROM nft_master nm
      INNER JOIN users u ON nm.user_id = u.user_id
      WHERE nm.buyback_date IS NULL
        AND u.has_approved_nft = TRUE
        AND nm.operation_start_date IS NOT NULL
        AND nm.operation_start_date <= p_date
        AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
        AND NOT EXISTS (
          SELECT 1 FROM buyback_requests br
          WHERE br.user_id = nm.user_id AND br.status = 'pending'
        )
      GROUP BY nm.user_id
    ) cnt
    WHERE ac.user_id = cnt.user_id;
  END IF;

  -- 3) 明細とログを削除
  DELETE FROM nft_daily_profit WHERE date = p_date;
  DELETE FROM user_referral_profit WHERE date = p_date;  -- 廃止済みだが念のため
  DELETE FROM daily_yield_log_v2 WHERE date = p_date;

  RETURN QUERY SELECT TRUE,
    format('%s の日利を削除しました（%s名の残高を合計$%s戻しました）',
      p_date::TEXT, v_users_reverted::TEXT, ROUND(v_total_reverted, 2)::TEXT);
END;
$$;

GRANT EXECUTE ON FUNCTION admin_cancel_yield_v2(DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_cancel_yield_v2(DATE) TO anon;
