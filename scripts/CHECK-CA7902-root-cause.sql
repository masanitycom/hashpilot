-- ========================================
-- CA7902 NFT重複の根本原因調査
-- ========================================

-- 1. nft_masterの詳細（created_atを確認）
SELECT
  id,
  user_id,
  nft_sequence,
  nft_type,
  nft_value,
  acquired_date,
  created_at,
  updated_at
FROM nft_master
WHERE user_id = 'CA7902'
ORDER BY created_at;

-- 2. purchasesの詳細
SELECT
  id,
  user_id,
  amount_usd,
  nft_quantity,
  admin_approved,
  admin_approved_at,
  admin_approved_by,
  created_at
FROM purchases
WHERE user_id = 'CA7902'
ORDER BY created_at;

-- 3. 同じ日にnft_masterに2枚以上作成された全ユーザー（同様の問題があるか確認）
SELECT
  user_id,
  acquired_date,
  COUNT(*) as nft_count,
  array_agg(id) as nft_ids
FROM nft_master
WHERE buyback_date IS NULL
GROUP BY user_id, acquired_date
HAVING COUNT(*) > 1
ORDER BY acquired_date;

-- 4. purchases.nft_quantity vs nft_master実際の枚数（不整合チェック）
WITH purchase_summary AS (
  SELECT
    user_id,
    SUM(nft_quantity) as purchased_nft_count
  FROM purchases
  WHERE admin_approved = true
  GROUP BY user_id
),
nft_summary AS (
  SELECT
    user_id,
    COUNT(*) as actual_nft_count
  FROM nft_master
  WHERE buyback_date IS NULL
  GROUP BY user_id
)
SELECT
  COALESCE(p.user_id, n.user_id) as user_id,
  COALESCE(p.purchased_nft_count, 0) as purchased,
  COALESCE(n.actual_nft_count, 0) as actual,
  COALESCE(n.actual_nft_count, 0) - COALESCE(p.purchased_nft_count, 0) as difference
FROM purchase_summary p
FULL OUTER JOIN nft_summary n ON p.user_id = n.user_id
WHERE COALESCE(n.actual_nft_count, 0) != COALESCE(p.purchased_nft_count, 0)
ORDER BY difference DESC;
