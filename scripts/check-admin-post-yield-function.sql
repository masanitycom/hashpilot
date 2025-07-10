-- admin_post_yield関数の確認と修正

-- 1. 既存の関数情報を確認
SELECT 
    'Function info' as info,
    proname as function_name,
    pronargs as arg_count,
    proargtypes
FROM pg_proc 
WHERE proname = 'admin_post_yield';

-- 2. 関数のパラメータ詳細確認
SELECT 
    'Function parameters' as info,
    routine_name,
    parameter_name,
    data_type,
    parameter_mode,
    ordinal_position
FROM information_schema.parameters
WHERE routine_name = 'admin_post_yield'
ORDER BY ordinal_position;

-- 3. 現在のadminsテーブル確認
SELECT 
    'Admin users' as info,
    email,
    is_active
FROM admins;

-- 4. 簡単な日利設定関数を作成（既存の関数が問題ある場合のバックアップ）
CREATE OR REPLACE FUNCTION simple_admin_post_yield(
  p_date DATE,
  p_yield_rate NUMERIC,
  p_margin_rate NUMERIC,
  p_is_month_end BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(
  status TEXT,
  total_users INTEGER,
  total_user_profit NUMERIC,
  total_company_profit NUMERIC,
  message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_count INTEGER := 0;
  v_total_user_profit NUMERIC := 0;
  v_total_company_profit NUMERIC := 0;
  v_user_rate NUMERIC;
  v_user_record RECORD;
BEGIN
  -- ユーザー利率を計算
  v_user_rate := p_yield_rate * (1 - p_margin_rate) * 0.6;

  -- daily_yield_logに記録
  INSERT INTO daily_yield_log (
    date, yield_rate, margin_rate, user_rate, is_month_end, created_at
  )
  VALUES (
    p_date, p_yield_rate, p_margin_rate, v_user_rate, p_is_month_end, NOW()
  )
  ON CONFLICT (date) DO UPDATE SET
    yield_rate = EXCLUDED.yield_rate,
    margin_rate = EXCLUDED.margin_rate,
    user_rate = EXCLUDED.user_rate,
    is_month_end = EXCLUDED.is_month_end,
    created_at = NOW();

  -- user_daily_profitテーブルの既存データを削除
  DELETE FROM user_daily_profit WHERE date = p_date;

  -- 各ユーザーの利益を計算して挿入
  FOR v_user_record IN
    SELECT 
      user_id,
      total_nft_count,
      cum_usdt
    FROM affiliate_cycle 
    WHERE total_nft_count > 0
  LOOP
    DECLARE
      v_base_amount NUMERIC;
      v_daily_profit NUMERIC;
      v_company_profit NUMERIC;
    BEGIN
      -- 基準金額（NFT数 × 1100）
      v_base_amount := v_user_record.total_nft_count * 1100;
      
      -- ユーザー利益計算
      v_daily_profit := v_base_amount * v_user_rate;
      
      -- 会社利益計算
      v_company_profit := v_base_amount * p_margin_rate + v_base_amount * (p_yield_rate - p_margin_rate) * 0.1;

      -- user_daily_profitに挿入
      INSERT INTO user_daily_profit (
        user_id, date, daily_profit, yield_rate, user_rate, base_amount, phase, created_at
      )
      VALUES (
        v_user_record.user_id, p_date, v_daily_profit, p_yield_rate, v_user_rate, v_base_amount, 'USDT', NOW()
      );

      v_user_count := v_user_count + 1;
      v_total_user_profit := v_total_user_profit + v_daily_profit;
      v_total_company_profit := v_total_company_profit + v_company_profit;
    END;
  END LOOP;

  -- 結果を返す
  RETURN QUERY SELECT 
    'SUCCESS'::TEXT,
    v_user_count::INTEGER,
    v_total_user_profit::NUMERIC,
    v_total_company_profit::NUMERIC,
    FORMAT('✅ 日利設定完了: %s名に総額$%s配布', v_user_count, ROUND(v_total_user_profit, 2))::TEXT;

EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT 
    'ERROR'::TEXT,
    0::INTEGER,
    0::NUMERIC,
    0::NUMERIC,
    FORMAT('エラー: %s', SQLERRM)::TEXT;
END;
$$;

-- 実行権限を設定
GRANT EXECUTE ON FUNCTION simple_admin_post_yield(DATE, NUMERIC, NUMERIC, BOOLEAN) TO anon;
GRANT EXECUTE ON FUNCTION simple_admin_post_yield(DATE, NUMERIC, NUMERIC, BOOLEAN) TO authenticated;

-- テスト実行（昨日の日付で）
SELECT * FROM simple_admin_post_yield('2025-07-09', 0.016, 0.30, false);