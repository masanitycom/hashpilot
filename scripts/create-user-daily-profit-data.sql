-- user_daily_profitデータを生成する管理関数

CREATE OR REPLACE FUNCTION admin_generate_daily_profit_data(
  p_admin_email TEXT,
  p_date DATE
)
RETURNS TABLE(
  status TEXT,
  affected_users INTEGER,
  total_profit NUMERIC,
  message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_exists BOOLEAN;
  v_yield_data RECORD;
  v_user_record RECORD;
  v_affected_count INTEGER := 0;
  v_total_profit NUMERIC := 0;
  v_daily_profit NUMERIC;
  v_base_amount NUMERIC;
BEGIN
  -- 管理者権限確認
  SELECT EXISTS(
    SELECT 1 FROM admins 
    WHERE email = p_admin_email AND is_active = true
  ) INTO v_admin_exists;

  IF NOT v_admin_exists THEN
    RETURN QUERY SELECT 
      'ERROR'::TEXT,
      0::INTEGER,
      0::NUMERIC,
      '管理者権限がありません'::TEXT;
    RETURN;
  END IF;

  -- 指定日の日利設定を取得
  SELECT date, yield_rate, margin_rate, user_rate
  INTO v_yield_data
  FROM daily_yield_log 
  WHERE date = p_date;

  IF NOT FOUND THEN
    RETURN QUERY SELECT 
      'ERROR'::TEXT,
      0::INTEGER,
      0::NUMERIC,
      FORMAT('指定日 %s の日利設定が見つかりません', p_date)::TEXT;
    RETURN;
  END IF;

  -- 既存のuser_daily_profitデータを削除（重複防止）
  DELETE FROM user_daily_profit WHERE date = p_date;

  -- affiliate_cycleの各ユーザーに対して利益を計算・挿入
  FOR v_user_record IN
    SELECT 
      user_id,
      total_nft_count,
      cum_usdt
    FROM affiliate_cycle 
    WHERE total_nft_count > 0
  LOOP
    -- 基準金額（NFT数 × 1100）
    v_base_amount := v_user_record.total_nft_count * 1100;
    
    -- 日利計算（基準金額 × ユーザー利率）
    v_daily_profit := v_base_amount * v_yield_data.user_rate;

    -- user_daily_profitテーブルに挿入
    INSERT INTO user_daily_profit (
      user_id,
      date,
      daily_profit,
      yield_rate,
      user_rate,
      base_amount,
      phase,
      created_at
    )
    VALUES (
      v_user_record.user_id,
      p_date,
      v_daily_profit,
      v_yield_data.yield_rate,
      v_yield_data.user_rate,
      v_base_amount,
      'USDT',
      NOW()
    );

    v_affected_count := v_affected_count + 1;
    v_total_profit := v_total_profit + v_daily_profit;
  END LOOP;

  -- 結果を返す
  RETURN QUERY SELECT 
    'SUCCESS'::TEXT,
    v_affected_count::INTEGER,
    v_total_profit::NUMERIC,
    FORMAT('✅ %s の利益データを生成: %s名のユーザーに総額$%s配布', 
           p_date, v_affected_count, ROUND(v_total_profit, 2))::TEXT;

EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT 
    'ERROR'::TEXT,
    0::INTEGER,
    0::NUMERIC,
    FORMAT('利益データ生成エラー: %s', SQLERRM)::TEXT;
END;
$$;

-- 実行権限を設定
GRANT EXECUTE ON FUNCTION admin_generate_daily_profit_data(TEXT, DATE) TO anon;
GRANT EXECUTE ON FUNCTION admin_generate_daily_profit_data(TEXT, DATE) TO authenticated;

-- 7/8の利益データを生成
SELECT * FROM admin_generate_daily_profit_data('basarasystems@gmail.com', '2025-07-08');

-- 7/9の利益データも生成（昨日の確定利益表示用）
SELECT * FROM admin_generate_daily_profit_data('basarasystems@gmail.com', '2025-07-09');

-- 結果確認
SELECT 
  'Generated data summary' as info,
  date,
  COUNT(*) as user_count,
  SUM(daily_profit) as total_profit,
  AVG(daily_profit) as avg_profit
FROM user_daily_profit 
GROUP BY date
ORDER BY date DESC;