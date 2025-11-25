-- ========================================
-- V2日利削除関数（完全版）
-- ========================================
-- 全テーブルを完全にロールバック
-- ========================================

CREATE OR REPLACE FUNCTION delete_daily_yield_v2(p_date DATE)
RETURNS JSONB
LANGUAGE plpgsql
AS $function$
DECLARE
  v_deleted_nft_daily_profit INTEGER := 0;
  v_deleted_referral_profit INTEGER := 0;
  v_deleted_auto_nft INTEGER := 0;
  v_deleted_purchases INTEGER := 0;
  v_affected_users INTEGER := 0;
  v_user_record RECORD;
BEGIN
  -- 1. この日に自動付与されたNFTの影響を受けるユーザーを記録
  CREATE TEMP TABLE IF NOT EXISTS temp_affected_users AS
  SELECT
    nm.user_id,
    COUNT(*) as auto_nft_count,
    ac.cum_usdt,
    ac.available_usdt,
    ac.auto_nft_count as current_auto_count,
    ac.total_nft_count as current_total_count
  FROM nft_master nm
  JOIN affiliate_cycle ac ON nm.user_id = ac.user_id
  WHERE nm.nft_type = 'auto' AND nm.acquired_date = p_date
  GROUP BY nm.user_id, ac.cum_usdt, ac.available_usdt, ac.auto_nft_count, ac.total_nft_count;

  SELECT COUNT(*) INTO v_affected_users FROM temp_affected_users;

  -- 2. affiliate_cycleを巻き戻す（自動NFT付与前の状態に）
  IF v_affected_users > 0 THEN
    FOR v_user_record IN SELECT * FROM temp_affected_users LOOP
      UPDATE affiliate_cycle
      SET
        cum_usdt = cum_usdt + (v_user_record.auto_nft_count * 2200),
        available_usdt = available_usdt - (v_user_record.auto_nft_count * 1100),
        auto_nft_count = auto_nft_count - v_user_record.auto_nft_count,
        total_nft_count = total_nft_count - v_user_record.auto_nft_count,
        phase = CASE WHEN (cum_usdt + (v_user_record.auto_nft_count * 2200)) >= 1100 THEN 'HOLD' ELSE 'USDT' END,
        updated_at = NOW()
      WHERE user_id = v_user_record.user_id;
    END LOOP;
  END IF;

  -- 3. 紹介報酬を巻き戻す（affiliate_cycleのcum_usdt, available_usdtから減算）
  FOR v_user_record IN
    SELECT user_id, SUM(profit_amount) as total_referral
    FROM user_referral_profit
    WHERE date = p_date
    GROUP BY user_id
  LOOP
    UPDATE affiliate_cycle
    SET
      cum_usdt = cum_usdt - v_user_record.total_referral,
      available_usdt = available_usdt - v_user_record.total_referral,
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id;
  END LOOP;

  -- 4. 個人利益を巻き戻す（affiliate_cycleのavailable_usdtから減算）
  FOR v_user_record IN
    SELECT user_id, SUM(daily_profit) as total_profit
    FROM nft_daily_profit
    WHERE date = p_date
    GROUP BY user_id
  LOOP
    UPDATE affiliate_cycle
    SET
      available_usdt = available_usdt - v_user_record.total_profit,
      updated_at = NOW()
    WHERE user_id = v_user_record.user_id;
  END LOOP;

  -- 5. 自動購入レコードを削除
  DELETE FROM purchases
  WHERE is_auto_purchase = true
    AND created_at::date = p_date;
  GET DIAGNOSTICS v_deleted_purchases = ROW_COUNT;

  -- 6. 自動付与NFTを削除
  DELETE FROM nft_master
  WHERE nft_type = 'auto'
    AND acquired_date = p_date;
  GET DIAGNOSTICS v_deleted_auto_nft = ROW_COUNT;

  -- 7. 紹介報酬を削除
  DELETE FROM user_referral_profit WHERE date = p_date;
  GET DIAGNOSTICS v_deleted_referral_profit = ROW_COUNT;

  -- 8. 個人利益を削除
  DELETE FROM nft_daily_profit WHERE date = p_date;
  GET DIAGNOSTICS v_deleted_nft_daily_profit = ROW_COUNT;

  -- 9. 日利ログを削除
  DELETE FROM daily_yield_log_v2 WHERE date = p_date;

  -- 10. 一時テーブルをクリーンアップ
  DROP TABLE IF EXISTS temp_affected_users;

  RETURN jsonb_build_object(
    'status', 'SUCCESS',
    'message', p_date || 'の日利データを完全に削除しました',
    'details', jsonb_build_object(
      'date', p_date,
      'deleted_nft_daily_profit', v_deleted_nft_daily_profit,
      'deleted_referral_profit', v_deleted_referral_profit,
      'deleted_auto_nft', v_deleted_auto_nft,
      'deleted_purchases', v_deleted_purchases,
      'affected_users', v_affected_users
    )
  );
END;
$function$;

SELECT '✅ V2日利削除関数を作成しました（全テーブル完全ロールバック）' as status;
