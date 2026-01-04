-- ========================================
-- 全ユーザーのNFT数不整合チェック
-- ========================================

-- 1. 9DDF45の詳細
SELECT '=== 9DDF45の詳細 ===' as section;
SELECT
  nm.id as nft_id,
  nm.acquired_date,
  nm.operation_start_date,
  nm.nft_type,
  nm.buyback_date
FROM nft_master nm
WHERE nm.user_id = '9DDF45'
ORDER BY nm.acquired_date, nm.id;

-- 2. 9DDF45の購入履歴
SELECT '=== 9DDF45の購入履歴 ===' as section;
SELECT
  p.id,
  p.created_at,
  p.nft_quantity,
  p.amount_usd,
  p.admin_approved,
  p.admin_approved_at,
  p.is_auto_purchase
FROM purchases p
WHERE p.user_id = '9DDF45'
ORDER BY p.created_at;

-- 3. 9DDF45のusersテーブル情報
SELECT '=== 9DDF45のユーザー情報 ===' as section;
SELECT
  user_id,
  total_purchases,
  has_approved_nft,
  operation_start_date
FROM users
WHERE user_id = '9DDF45';

-- 4. 全ユーザーのNFT数比較（nft_master vs purchases）
SELECT '=== NFT数不整合ユーザー一覧 ===' as section;
SELECT
  u.user_id,
  u.email,
  u.total_purchases,
  FLOOR(u.total_purchases / 1100) as expected_nft_from_purchases,
  nm_count.nft_count as actual_nft_count,
  nm_count.nft_count - FLOOR(u.total_purchases / 1100) as difference,
  p_count.purchase_nft_total as purchase_records_nft_total
FROM users u
LEFT JOIN (
  SELECT user_id, COUNT(*) as nft_count
  FROM nft_master
  WHERE buyback_date IS NULL
  GROUP BY user_id
) nm_count ON u.user_id = nm_count.user_id
LEFT JOIN (
  SELECT user_id, SUM(nft_quantity) as purchase_nft_total
  FROM purchases
  WHERE admin_approved = true
  GROUP BY user_id
) p_count ON u.user_id = p_count.user_id
WHERE u.has_approved_nft = true
  AND (nm_count.nft_count != FLOOR(u.total_purchases / 1100)
       OR nm_count.nft_count != p_count.purchase_nft_total)
ORDER BY ABS(nm_count.nft_count - FLOOR(u.total_purchases / 1100)) DESC;

-- 5. affiliate_cycleのauto_nft_countとnft_masterの自動NFT数比較
SELECT '=== 自動NFT数不整合 ===' as section;
SELECT
  ac.user_id,
  ac.auto_nft_count as cycle_auto_count,
  nm_auto.auto_nft_count as master_auto_count,
  ac.auto_nft_count - COALESCE(nm_auto.auto_nft_count, 0) as difference
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, COUNT(*) as auto_nft_count
  FROM nft_master
  WHERE nft_type = 'auto' AND buyback_date IS NULL
  GROUP BY user_id
) nm_auto ON ac.user_id = nm_auto.user_id
WHERE ac.auto_nft_count > 0
   OR nm_auto.auto_nft_count > 0
HAVING ac.auto_nft_count != COALESCE(nm_auto.auto_nft_count, 0);

-- 6. 全体統計
SELECT '=== 全体NFT統計 ===' as section;
SELECT
  (SELECT COUNT(*) FROM nft_master WHERE buyback_date IS NULL) as total_active_nfts,
  (SELECT SUM(nft_quantity) FROM purchases WHERE admin_approved = true) as total_purchased_nfts,
  (SELECT COUNT(*) FROM nft_master WHERE nft_type = 'auto' AND buyback_date IS NULL) as total_auto_nfts,
  (SELECT COUNT(*) FROM nft_master WHERE nft_type = 'manual' AND buyback_date IS NULL) as total_manual_nfts;
