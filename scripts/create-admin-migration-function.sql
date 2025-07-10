-- 管理者専用のデータ移行関数を作成

-- 1. 既存の関数があれば削除
DROP FUNCTION IF EXISTS admin_migrate_purchases_to_affiliate_cycle(TEXT);

-- 2. 管理者専用データ移行関数の作成
CREATE OR REPLACE FUNCTION admin_migrate_purchases_to_affiliate_cycle(p_admin_email TEXT)
RETURNS TABLE(
  status TEXT,
  migrated_users INTEGER,
  total_nft_count INTEGER,
  total_amount NUMERIC,
  message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_exists BOOLEAN;
  v_migrated_count INTEGER := 0;
  v_total_nfts INTEGER := 0;
  v_total_amount NUMERIC := 0;
  v_user_record RECORD;
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
      0::INTEGER,
      0::NUMERIC,
      '管理者権限がありません'::TEXT;
    RETURN;
  END IF;

  -- 承認済み購入データをユーザーごとに集計してaffiliate_cycleに挿入
  FOR v_user_record IN
    SELECT 
      p.user_id,
      SUM(p.nft_quantity) as total_nft_count,
      SUM(p.amount_usd::numeric) as cum_usdt,
      MIN(p.created_at) as cycle_start_date
    FROM purchases p
    WHERE 
      p.admin_approved = true
      AND p.user_id NOT IN (SELECT user_id FROM affiliate_cycle)
    GROUP BY p.user_id
    HAVING SUM(p.nft_quantity) > 0
  LOOP
    -- affiliate_cycleテーブルに挿入
    INSERT INTO affiliate_cycle (
      user_id,
      phase,
      total_nft_count,
      cum_usdt,
      cycle_start_date,
      last_updated
    )
    VALUES (
      v_user_record.user_id,
      'USDT',
      v_user_record.total_nft_count,
      v_user_record.cum_usdt,
      v_user_record.cycle_start_date,
      NOW()
    );

    v_migrated_count := v_migrated_count + 1;
    v_total_nfts := v_total_nfts + v_user_record.total_nft_count;
    v_total_amount := v_total_amount + v_user_record.cum_usdt;
  END LOOP;

  -- 結果を返す
  RETURN QUERY SELECT 
    'SUCCESS'::TEXT,
    v_migrated_count::INTEGER,
    v_total_nfts::INTEGER,
    v_total_amount::NUMERIC,
    FORMAT('✅ 移行完了: %s名のユーザーデータを移行しました（NFT総数: %s、総投資額: $%s）', 
           v_migrated_count, v_total_nfts, v_total_amount)::TEXT;

EXCEPTION WHEN OTHERS THEN
  RETURN QUERY SELECT 
    'ERROR'::TEXT,
    0::INTEGER,
    0::INTEGER,
    0::NUMERIC,
    FORMAT('移行エラー: %s', SQLERRM)::TEXT;
END;
$$;

-- 3. 関数実行権限を設定
GRANT EXECUTE ON FUNCTION admin_migrate_purchases_to_affiliate_cycle(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION admin_migrate_purchases_to_affiliate_cycle(TEXT) TO authenticated;

-- 4. テスト用に関数の情報を表示
SELECT 
  'Function created' as status,
  'admin_migrate_purchases_to_affiliate_cycle' as function_name,
  '管理者専用データ移行関数が作成されました' as message;