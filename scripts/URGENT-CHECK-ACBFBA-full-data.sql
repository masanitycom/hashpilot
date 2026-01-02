-- ========================================
-- ACBFBA 緊急調査（85 NFT）
-- ========================================

-- 1. usersテーブル
SELECT '=== 1. users テーブル ===' as section;
SELECT
  user_id,
  email,
  total_purchases,
  has_approved_nft,
  operation_start_date,
  referrer_user_id,
  created_at
FROM users
WHERE user_id = 'ACBFBA';

-- 2. purchases（購入履歴）
SELECT '=== 2. purchases テーブル ===' as section;
SELECT
  id,
  amount_usd,
  admin_approved,
  is_auto_purchase,
  created_at
FROM purchases
WHERE user_id = 'ACBFBA'
ORDER BY created_at;

-- 3. nft_master（NFT保有）
SELECT '=== 3. nft_master テーブル ===' as section;
SELECT
  COUNT(*) as nft_count
FROM nft_master
WHERE user_id = 'ACBFBA'
  AND buyback_date IS NULL;

-- 4. NFT数の不一致
SELECT '=== 4. NFT数不一致確認 ===' as section;
SELECT
  u.user_id,
  u.total_purchases,
  FLOOR(u.total_purchases / 1100) as expected_nft,
  COUNT(nm.id) as actual_nft,
  FLOOR(u.total_purchases / 1100) - COUNT(nm.id) as missing_nft
FROM users u
LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE u.user_id = 'ACBFBA'
GROUP BY u.user_id, u.total_purchases;

-- 5. 日利の確認
SELECT '=== 5. ACBFBA: 12月日利合計 ===' as section;
SELECT
  COUNT(*) as record_count,
  COUNT(DISTINCT date) as days,
  SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE user_id = 'ACBFBA'
  AND date >= '2025-12-01';

-- 6. affiliate_cycle
SELECT '=== 6. affiliate_cycle ===' as section;
SELECT * FROM affiliate_cycle WHERE user_id = 'ACBFBA';
