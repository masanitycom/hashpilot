-- ========================================
-- 差異1個の原因調査
-- ========================================

-- 1. 購入承認されたがnft_masterにないユーザー
SELECT '=== 購入承認済みだがNFT数が足りないユーザー ===' as section;
SELECT
  u.user_id,
  u.email,
  p.purchase_nft_total,
  COALESCE(nm.nft_count, 0) as nft_master_count,
  p.purchase_nft_total - COALESCE(nm.nft_count, 0) as missing
FROM users u
JOIN (
  SELECT user_id, SUM(nft_quantity) as purchase_nft_total
  FROM purchases
  WHERE admin_approved = true
  GROUP BY user_id
) p ON u.user_id = p.user_id
LEFT JOIN (
  SELECT user_id, COUNT(*) as nft_count
  FROM nft_master
  GROUP BY user_id
) nm ON u.user_id = nm.user_id
WHERE p.purchase_nft_total > COALESCE(nm.nft_count, 0)
ORDER BY p.purchase_nft_total - COALESCE(nm.nft_count, 0) DESC;

-- 2. 買い戻し済みNFT
SELECT '=== 買い戻し済みNFT ===' as section;
SELECT
  user_id,
  COUNT(*) as buyback_count
FROM nft_master
WHERE buyback_date IS NOT NULL
GROUP BY user_id
ORDER BY buyback_count DESC;

-- 3. 全NFT数（買い戻し含む）
SELECT '=== 全NFT数（買い戻し含む）===' as section;
SELECT
  COUNT(*) as total_all_nfts,
  COUNT(CASE WHEN buyback_date IS NULL THEN 1 END) as active_nfts,
  COUNT(CASE WHEN buyback_date IS NOT NULL THEN 1 END) as buyback_nfts
FROM nft_master;
