-- ========================================
-- NFT数が中途半端な日に変わる原因調査
-- ========================================

-- 考えられる原因:
-- 1. NFT買い取り（buyback）→ NFT数が減る
-- 2. 自動NFT付与 → NFT数が増える（$2,200到達時）
-- 3. 手動NFT購入承認 → NFT数が増える
-- 4. operation_start_dateが中途半端な日のユーザー

-- ========================================
-- 1. 12月のNFT買い取り履歴
-- ========================================
SELECT '=== 1. 12月のNFT買い取り ===' as section;
SELECT
  nm.user_id,
  u.email,
  nm.buyback_date,
  nm.nft_type,
  nm.acquired_date
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date >= '2025-12-01'
  AND nm.buyback_date <= '2025-12-31'
ORDER BY nm.buyback_date;

-- ========================================
-- 2. 12月の自動NFT付与履歴
-- ========================================
SELECT '=== 2. 12月の自動NFT付与 ===' as section;
SELECT
  nm.user_id,
  u.email,
  nm.acquired_date,
  nm.created_at,
  nm.nft_type
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.nft_type = 'auto'
  AND nm.acquired_date >= '2025-12-01'
  AND nm.acquired_date <= '2025-12-31'
ORDER BY nm.acquired_date;

-- ========================================
-- 3. 12月の手動NFT購入承認履歴
-- ========================================
SELECT '=== 3. 12月の手動NFT購入承認 ===' as section;
SELECT
  p.user_id,
  u.email,
  p.admin_approved_at::date as approved_date,
  p.usdt_amount,
  p.nft_type,
  u.operation_start_date
FROM purchases p
JOIN users u ON p.user_id = u.user_id
WHERE p.admin_approved = true
  AND p.admin_approved_at >= '2025-12-01'
  AND p.admin_approved_at < '2026-01-01'
  AND p.nft_type != 'auto'
ORDER BY p.admin_approved_at;

-- ========================================
-- 4. operation_start_dateの分布（12月）
-- ========================================
SELECT '=== 4. 運用開始日の分布 ===' as section;
SELECT
  operation_start_date,
  COUNT(*) as user_count,
  SUM(total_purchases / 1100) as total_nfts
FROM users
WHERE operation_start_date >= '2025-12-01'
  AND operation_start_date <= '2025-12-31'
  AND total_purchases > 0
GROUP BY operation_start_date
ORDER BY operation_start_date;

-- ========================================
-- 5. 日別のNFT数変化の詳細
-- ========================================
SELECT '=== 5. 12/6 NFT減少の原因 ===' as section;
SELECT
  nm.user_id,
  u.email,
  nm.buyback_date,
  '買い取り' as reason
FROM nft_master nm
JOIN users u ON nm.user_id = u.user_id
WHERE nm.buyback_date = '2025-12-06';

SELECT '=== 6. 12/7 NFT増加の原因 ===' as section;
-- 12/7に運用開始したユーザー
SELECT
  u.user_id,
  u.email,
  u.operation_start_date,
  u.total_purchases,
  FLOOR(u.total_purchases / 1100) as nft_count,
  '運用開始' as reason
FROM users u
WHERE u.operation_start_date = '2025-12-07'
  AND u.total_purchases > 0
UNION ALL
-- 12/7に承認されたNFT
SELECT
  p.user_id,
  u.email,
  p.admin_approved_at::date,
  p.usdt_amount,
  1 as nft_count,
  'NFT承認' as reason
FROM purchases p
JOIN users u ON p.user_id = u.user_id
WHERE p.admin_approved_at::date = '2025-12-07'
  AND p.admin_approved = true;

-- ========================================
-- 6. 運用開始日が1日/15日以外のユーザー
-- ========================================
SELECT '=== 7. 運用開始日が1日/15日以外 ===' as section;
SELECT
  user_id,
  email,
  operation_start_date,
  total_purchases,
  FLOOR(total_purchases / 1100) as nft_count
FROM users
WHERE operation_start_date IS NOT NULL
  AND total_purchases > 0
  AND EXTRACT(DAY FROM operation_start_date) NOT IN (1, 15)
ORDER BY operation_start_date DESC
LIMIT 20;

-- ========================================
-- 7. 12月の日別NFT変動サマリー
-- ========================================
SELECT '=== 8. 12月日別NFT変動 ===' as section;

-- 各日の運用開始ユーザー数
SELECT
  '運用開始' as type,
  operation_start_date as date,
  COUNT(*) as user_count,
  SUM(FLOOR(total_purchases / 1100)) as nft_count
FROM users
WHERE operation_start_date >= '2025-12-01'
  AND operation_start_date <= '2025-12-31'
  AND total_purchases > 0
GROUP BY operation_start_date

UNION ALL

-- 各日の買い取り
SELECT
  '買い取り' as type,
  buyback_date as date,
  COUNT(*) as user_count,
  -COUNT(*) as nft_count
FROM nft_master
WHERE buyback_date >= '2025-12-01'
  AND buyback_date <= '2025-12-31'
GROUP BY buyback_date

UNION ALL

-- 各日の自動NFT付与
SELECT
  '自動付与' as type,
  acquired_date as date,
  COUNT(*) as user_count,
  COUNT(*) as nft_count
FROM nft_master
WHERE nft_type = 'auto'
  AND acquired_date >= '2025-12-01'
  AND acquired_date <= '2025-12-31'
GROUP BY acquired_date

ORDER BY date, type;
