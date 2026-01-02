-- ========================================
-- 59C23C NFT状態確認
-- ========================================

-- 1. ユーザー基本情報
SELECT '=== 1. ユーザー情報 ===' as section;
SELECT
  user_id,
  email,
  total_purchases,
  has_approved_nft,
  operation_start_date
FROM users
WHERE user_id = '59C23C';

-- 2. affiliate_cycle状態
SELECT '=== 2. affiliate_cycle ===' as section;
SELECT
  user_id,
  cum_usdt,
  available_usdt,
  phase,
  withdrawn_referral_usdt,
  auto_nft_count,
  manual_nft_count,
  total_nft_count
FROM affiliate_cycle
WHERE user_id = '59C23C';

-- 3. NFT一覧（nft_master）
SELECT '=== 3. nft_master ===' as section;
SELECT
  id,
  user_id,
  nft_type,
  acquired_date,
  buyback_date,
  created_at
FROM nft_master
WHERE user_id = '59C23C'
ORDER BY acquired_date;

-- 4. 購入履歴
SELECT '=== 4. purchases ===' as section;
SELECT
  id,
  user_id,
  amount,
  admin_approved,
  approved_at,
  is_auto_purchase,
  cycle_number_at_purchase,
  created_at
FROM purchases
WHERE user_id = '59C23C'
ORDER BY created_at;

-- 5. 自動NFT付与の条件確認
-- cum_usdt >= 2200 で自動付与
SELECT '=== 5. 自動NFT付与条件 ===' as section;
SELECT
  user_id,
  cum_usdt,
  CASE
    WHEN cum_usdt >= 2200 THEN '✓ 自動NFT付与対象（$2,200以上）'
    WHEN cum_usdt >= 1100 THEN '🔒 HOLDフェーズ（$1,100以上$2,200未満）'
    ELSE '💵 USDTフェーズ（$1,100未満）'
  END as status,
  auto_nft_count,
  2200 - cum_usdt as remaining_to_auto_nft
FROM affiliate_cycle
WHERE user_id = '59C23C';

-- 6. 紹介報酬履歴
SELECT '=== 6. 月次紹介報酬 ===' as section;
SELECT
  year,
  month,
  SUM(profit_amount) as total_referral
FROM user_referral_profit_monthly
WHERE user_id = '59C23C'
GROUP BY year, month
ORDER BY year, month;
