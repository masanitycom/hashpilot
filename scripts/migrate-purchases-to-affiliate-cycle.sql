-- purchases データを affiliate_cycle テーブルに移行

-- 1. 現在の状況確認
SELECT 'Current affiliate_cycle count' as info, COUNT(*) as count FROM affiliate_cycle;
SELECT 'Current purchases count' as info, COUNT(*) as count FROM purchases WHERE admin_approved = true;

-- 2. 承認済み購入データからユーザーごとのNFT数を集計
WITH user_nft_summary AS (
  SELECT 
    p.user_id,
    COUNT(*) as purchase_count,
    SUM(p.nft_quantity) as total_nft_count,
    SUM(p.amount_usd::numeric) as total_amount_usd,
    MIN(p.purchase_date) as first_purchase_date,
    MAX(p.purchase_date) as latest_purchase_date
  FROM purchases p
  WHERE p.admin_approved = true
  GROUP BY p.user_id
)
SELECT 
  'User NFT Summary' as info,
  user_id,
  purchase_count,
  total_nft_count,
  total_amount_usd,
  first_purchase_date,
  latest_purchase_date
FROM user_nft_summary
ORDER BY total_amount_usd DESC;

-- 3. affiliate_cycle テーブルにデータを挿入（重複チェック付き）
INSERT INTO affiliate_cycle (
  user_id,
  phase,
  total_nft_count,
  cum_usdt,
  cycle_start_date,
  last_updated
)
SELECT 
  p.user_id,
  'USDT' as phase,  -- 初期フェーズはUSDT
  SUM(p.nft_quantity) as total_nft_count,
  SUM(p.amount_usd::numeric) as cum_usdt,
  MIN(p.purchase_date) as cycle_start_date,
  NOW() as last_updated
FROM purchases p
WHERE 
  p.admin_approved = true
  AND p.user_id NOT IN (SELECT user_id FROM affiliate_cycle)  -- 重複防止
GROUP BY p.user_id
HAVING SUM(p.nft_quantity) > 0;  -- NFT数が0より大きい場合のみ

-- 4. 移行結果確認
SELECT 'Migration result - affiliate_cycle' as info, COUNT(*) as new_count FROM affiliate_cycle;

-- 5. データ整合性チェック
SELECT 
  'Data consistency check' as check_type,
  ac.user_id,
  ac.total_nft_count as affiliate_cycle_nft,
  COALESCE(SUM(p.nft_quantity), 0) as purchases_nft_total,
  ac.cum_usdt as affiliate_cycle_amount,
  COALESCE(SUM(p.amount_usd::numeric), 0) as purchases_amount_total,
  CASE 
    WHEN ac.total_nft_count = COALESCE(SUM(p.nft_quantity), 0) THEN 'MATCH'
    ELSE 'MISMATCH'
  END as nft_consistency,
  CASE 
    WHEN ac.cum_usdt = COALESCE(SUM(p.amount_usd::numeric), 0) THEN 'MATCH'
    ELSE 'MISMATCH'
  END as amount_consistency
FROM affiliate_cycle ac
LEFT JOIN purchases p ON ac.user_id = p.user_id AND p.admin_approved = true
GROUP BY ac.user_id, ac.total_nft_count, ac.cum_usdt
ORDER BY ac.cum_usdt DESC
LIMIT 10;

-- 6. users テーブルの total_purchases との整合性チェック
SELECT 
  'Users table consistency' as check_type,
  u.user_id,
  u.total_purchases as users_total_purchases,
  ac.cum_usdt as affiliate_cycle_amount,
  FLOOR(u.total_purchases / 1100) as expected_nft_from_users_table,
  ac.total_nft_count as actual_nft_in_affiliate_cycle,
  CASE 
    WHEN u.total_purchases = ac.cum_usdt THEN 'MATCH'
    ELSE 'MISMATCH'
  END as amount_match
FROM users u
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.total_purchases > 0
ORDER BY u.total_purchases DESC
LIMIT 10;