-- affiliate_cycleテーブルの構造確認と修正

-- 1. 現在のテーブル構造を確認
SELECT 
  'Current affiliate_cycle structure' as info,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'affiliate_cycle' 
ORDER BY ordinal_position;

-- 2. 不足しているカラムを追加
ALTER TABLE affiliate_cycle 
ADD COLUMN IF NOT EXISTS cycle_start_date TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS last_updated TIMESTAMPTZ DEFAULT NOW();

-- 3. 修正後の構造確認
SELECT 
  'Updated affiliate_cycle structure' as info,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'affiliate_cycle' 
ORDER BY ordinal_position;

-- 4. 管理者移行関数を更新（カラム不足に対応）
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
  v_cycle_start_date TIMESTAMPTZ;
  v_has_cycle_start_date BOOLEAN;
  v_has_last_updated BOOLEAN;
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

  -- テーブル構造確認
  SELECT EXISTS(
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'affiliate_cycle' AND column_name = 'cycle_start_date'
  ) INTO v_has_cycle_start_date;

  SELECT EXISTS(
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'affiliate_cycle' AND column_name = 'last_updated'
  ) INTO v_has_last_updated;

  -- 承認済み購入データをユーザーごとに集計してaffiliate_cycleに挿入
  FOR v_user_record IN
    SELECT 
      p.user_id,
      SUM(p.nft_quantity) as total_nft_count,
      SUM(p.amount_usd::numeric) as cum_usdt,
      MIN(p.created_at) as first_purchase_date
    FROM purchases p
    WHERE 
      p.admin_approved = true
      AND p.user_id NOT IN (SELECT user_id FROM affiliate_cycle)
    GROUP BY p.user_id
    HAVING SUM(p.nft_quantity) > 0
  LOOP
    -- カラムの存在に応じて動的にINSERT
    IF v_has_cycle_start_date AND v_has_last_updated THEN
      INSERT INTO affiliate_cycle (
        user_id, phase, total_nft_count, cum_usdt, cycle_start_date, last_updated
      )
      VALUES (
        v_user_record.user_id, 'USDT', v_user_record.total_nft_count, 
        v_user_record.cum_usdt, v_user_record.first_purchase_date, NOW()
      );
    ELSIF v_has_cycle_start_date THEN
      INSERT INTO affiliate_cycle (
        user_id, phase, total_nft_count, cum_usdt, cycle_start_date
      )
      VALUES (
        v_user_record.user_id, 'USDT', v_user_record.total_nft_count, 
        v_user_record.cum_usdt, v_user_record.first_purchase_date
      );
    ELSIF v_has_last_updated THEN
      INSERT INTO affiliate_cycle (
        user_id, phase, total_nft_count, cum_usdt, last_updated
      )
      VALUES (
        v_user_record.user_id, 'USDT', v_user_record.total_nft_count, 
        v_user_record.cum_usdt, NOW()
      );
    ELSE
      -- 基本カラムのみ
      INSERT INTO affiliate_cycle (
        user_id, phase, total_nft_count, cum_usdt
      )
      VALUES (
        v_user_record.user_id, 'USDT', v_user_record.total_nft_count, 
        v_user_record.cum_usdt
      );
    END IF;

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

-- 5. 確認メッセージ
SELECT 'affiliate_cycle table structure fixed and function updated' as result;