-- 運用開始日を安全に変更するRPC関数
-- 運用開始日を変更した場合、その日付より前の日利データを自動削除

CREATE OR REPLACE FUNCTION update_operation_start_date_safe(
  p_user_id VARCHAR,
  p_new_operation_start_date DATE,
  p_admin_email VARCHAR
)
RETURNS TABLE(
  status TEXT,
  message TEXT,
  details JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_record RECORD;
  v_old_operation_start_date DATE;
  v_deleted_profit_count INTEGER := 0;
  v_deleted_profit_sum NUMERIC := 0;
  v_deleted_referral_count INTEGER := 0;
  v_deleted_referral_sum NUMERIC := 0;
BEGIN
  -- ユーザー存在確認
  SELECT
    u.user_id,
    u.email,
    u.operation_start_date
  INTO v_user_record
  FROM users u
  WHERE u.user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT
      'ERROR'::TEXT,
      format('ユーザー %s が見つかりません', p_user_id)::TEXT,
      NULL::JSONB;
    RETURN;
  END IF;

  v_old_operation_start_date := v_user_record.operation_start_date;

  -- 新しい運用開始日が未来の場合、その日より前の日利データを削除
  IF p_new_operation_start_date IS NOT NULL THEN

    -- 削除対象の日利データを集計
    SELECT
      COUNT(*),
      COALESCE(SUM(CAST(daily_profit AS NUMERIC)), 0)
    INTO v_deleted_profit_count, v_deleted_profit_sum
    FROM nft_daily_profit
    WHERE user_id = p_user_id
      AND date < p_new_operation_start_date;

    -- 削除対象の紹介報酬データを集計
    SELECT
      COUNT(*),
      COALESCE(SUM(CAST(amount AS NUMERIC)), 0)
    INTO v_deleted_referral_count, v_deleted_referral_sum
    FROM user_referral_profit
    WHERE user_id = p_user_id
      AND date < p_new_operation_start_date;

    -- 日利データを削除
    DELETE FROM nft_daily_profit
    WHERE user_id = p_user_id
      AND date < p_new_operation_start_date;

    -- 紹介報酬データを削除（自分への報酬）
    DELETE FROM user_referral_profit
    WHERE user_id = p_user_id
      AND date < p_new_operation_start_date;

    -- affiliate_cycleを更新（削除した分を差し引く）
    IF v_deleted_profit_sum != 0 OR v_deleted_referral_sum != 0 THEN
      UPDATE affiliate_cycle
      SET
        available_usdt = GREATEST(available_usdt - v_deleted_profit_sum - v_deleted_referral_sum, 0),
        cum_usdt = GREATEST(cum_usdt - v_deleted_referral_sum, 0),
        updated_at = NOW()
      WHERE user_id = p_user_id;
    END IF;
  END IF;

  -- ユーザーの運用開始日を更新
  UPDATE users
  SET
    operation_start_date = p_new_operation_start_date,
    updated_at = NOW()
  WHERE user_id = p_user_id;

  -- 成功
  RETURN QUERY SELECT
    'SUCCESS'::TEXT,
    format('運用開始日を %s に変更しました', p_new_operation_start_date)::TEXT,
    jsonb_build_object(
      'user_id', p_user_id,
      'email', v_user_record.email,
      'old_operation_start_date', v_old_operation_start_date,
      'new_operation_start_date', p_new_operation_start_date,
      'deleted_profit', jsonb_build_object(
        'count', v_deleted_profit_count,
        'sum', v_deleted_profit_sum
      ),
      'deleted_referral', jsonb_build_object(
        'count', v_deleted_referral_count,
        'sum', v_deleted_referral_sum
      ),
      'admin_email', p_admin_email,
      'executed_at', NOW()
    );

EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT
      'ERROR'::TEXT,
      format('エラー: %s', SQLERRM)::TEXT,
      jsonb_build_object('error_detail', SQLERRM);
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION update_operation_start_date_safe TO authenticated;

-- 確認
SELECT 'update_operation_start_date_safe関数を作成しました' as result;
