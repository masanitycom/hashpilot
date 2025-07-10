-- 管理者専用のaffiliate_cycleデータ確認関数

CREATE OR REPLACE FUNCTION admin_check_affiliate_cycle_data(p_admin_email TEXT)
RETURNS TABLE(
  user_id TEXT,
  phase VARCHAR,
  total_nft_count INTEGER,
  cum_usdt NUMERIC,
  available_usdt NUMERIC,
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_exists BOOLEAN;
BEGIN
  -- 管理者権限確認
  SELECT EXISTS(
    SELECT 1 FROM admins 
    WHERE email = p_admin_email AND is_active = true
  ) INTO v_admin_exists;

  IF NOT v_admin_exists THEN
    RAISE EXCEPTION '管理者権限がありません';
  END IF;

  -- affiliate_cycleテーブルの全データを取得
  RETURN QUERY 
  SELECT 
    ac.user_id,
    ac.phase,
    ac.total_nft_count,
    ac.cum_usdt,
    ac.available_usdt,
    ac.created_at,
    ac.updated_at
  FROM affiliate_cycle ac
  ORDER BY ac.cum_usdt DESC;

END;
$$;

-- 実行権限を設定
GRANT EXECUTE ON FUNCTION admin_check_affiliate_cycle_data(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION admin_check_affiliate_cycle_data(TEXT) TO authenticated;

-- 直接確認用の統計関数も作成
CREATE OR REPLACE FUNCTION admin_get_migration_stats(p_admin_email TEXT)
RETURNS TABLE(
  table_name TEXT,
  total_records INTEGER,
  total_amount NUMERIC,
  sample_data JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_exists BOOLEAN;
BEGIN
  -- 管理者権限確認
  SELECT EXISTS(
    SELECT 1 FROM admins 
    WHERE email = p_admin_email AND is_active = true
  ) INTO v_admin_exists;

  IF NOT v_admin_exists THEN
    RAISE EXCEPTION '管理者権限がありません';
  END IF;

  -- affiliate_cycle統計
  RETURN QUERY 
  SELECT 
    'affiliate_cycle'::TEXT,
    COUNT(*)::INTEGER,
    SUM(ac.cum_usdt)::NUMERIC,
    jsonb_agg(
      jsonb_build_object(
        'user_id', ac.user_id,
        'nft_count', ac.total_nft_count,
        'amount', ac.cum_usdt
      )
    ) FILTER (WHERE ac.user_id IS NOT NULL)
  FROM affiliate_cycle ac;

  -- purchases統計（承認済み）
  RETURN QUERY 
  SELECT 
    'purchases_approved'::TEXT,
    COUNT(*)::INTEGER,
    SUM(p.amount_usd::NUMERIC)::NUMERIC,
    jsonb_agg(
      jsonb_build_object(
        'user_id', p.user_id,
        'nft_quantity', p.nft_quantity,
        'amount', p.amount_usd
      )
    ) FILTER (WHERE p.user_id IS NOT NULL)
  FROM purchases p
  WHERE p.admin_approved = true
  LIMIT 5;

END;
$$;

-- 実行権限を設定
GRANT EXECUTE ON FUNCTION admin_get_migration_stats(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION admin_get_migration_stats(TEXT) TO authenticated;

SELECT 'Admin check functions created successfully' as result;