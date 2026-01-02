-- ========================================
-- ACACDB 緊急調査
-- ========================================

-- 1. usersテーブルの情報
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
WHERE user_id = 'ACACDB';

-- 2. purchasesテーブル（購入履歴）
SELECT '=== 2. purchases テーブル ===' as section;
SELECT
  id,
  amount_usd,
  admin_approved,
  is_auto_purchase,
  created_at
FROM purchases
WHERE user_id = 'ACACDB'
ORDER BY created_at;

-- 3. nft_master（NFT保有）
SELECT '=== 3. nft_master テーブル ===' as section;
SELECT
  id,
  nft_type,
  acquired_date,
  buyback_date,
  created_at
FROM nft_master
WHERE user_id = 'ACACDB'
ORDER BY acquired_date;

-- 4. ACACDBを紹介者とするユーザー
SELECT '=== 4. ACACDBが紹介したユーザー ===' as section;
SELECT
  user_id,
  email,
  total_purchases,
  operation_start_date,
  created_at
FROM users
WHERE referrer_user_id = 'ACACDB';

-- 5. ACACDBの紹介報酬（月次）
SELECT '=== 5. ACACDBの月次紹介報酬 ===' as section;
SELECT *
FROM user_referral_profit_monthly
WHERE user_id = 'ACACDB';

-- 6. ACACDBへの紹介報酬の元ユーザー確認
SELECT '=== 6. 紹介報酬の元ユーザー詳細 ===' as section;
SELECT
  urpm.user_id,
  urpm.child_user_id,
  urpm.referral_level,
  urpm.profit_amount,
  u.referrer_user_id as child_referrer
FROM user_referral_profit_monthly urpm
LEFT JOIN users u ON urpm.child_user_id = u.user_id
WHERE urpm.user_id = 'ACACDB';

-- 7. total_purchasesの確認
SELECT '=== 7. total_purchases確認 ===' as section;
SELECT
  user_id,
  total_purchases,
  total_purchases / 1100 as expected_nft_count
FROM users
WHERE user_id = 'ACACDB';

-- 8. NFT数の不一致確認
SELECT '=== 8. NFT数不一致 ===' as section;
SELECT
  u.user_id,
  u.total_purchases,
  u.total_purchases / 1100 as expected_nft,
  COUNT(nm.id) as actual_nft,
  u.total_purchases / 1100 - COUNT(nm.id) as missing_nft
FROM users u
LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE u.user_id = 'ACACDB'
GROUP BY u.user_id, u.total_purchases;
