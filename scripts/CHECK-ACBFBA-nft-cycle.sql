-- ========================================
-- ACBFBA のNFTサイクル確認
-- ========================================

-- 1. affiliate_cycle状態
SELECT '=== 1. affiliate_cycle ===' as section;
SELECT
  user_id,
  cum_usdt,
  available_usdt,
  phase,
  auto_nft_count,
  manual_nft_count,
  total_nft_count,
  withdrawn_referral_usdt
FROM affiliate_cycle
WHERE user_id = 'ACBFBA';

-- 2. NFT保有状況
SELECT '=== 2. NFT保有状況 ===' as section;
SELECT
  id,
  nft_type,
  acquired_date,
  buyback_date
FROM nft_master
WHERE user_id = 'ACBFBA'
ORDER BY acquired_date;

-- 3. 紹介報酬累計
SELECT '=== 3. 紹介報酬累計 ===' as section;
SELECT
  SUM(profit_amount) as total_referral,
  COUNT(*) as record_count
FROM user_referral_profit_monthly
WHERE user_id = 'ACBFBA';

-- 4. 月別紹介報酬
SELECT '=== 4. 月別紹介報酬 ===' as section;
SELECT
  year,
  month,
  SUM(profit_amount) as monthly_referral
FROM user_referral_profit_monthly
WHERE user_id = 'ACBFBA'
GROUP BY year, month
ORDER BY year, month;

-- 5. 12月の紹介報酬詳細
SELECT '=== 5. 12月紹介報酬詳細 ===' as section;
SELECT
  referral_level,
  SUM(profit_amount) as total,
  COUNT(*) as count
FROM user_referral_profit_monthly
WHERE user_id = 'ACBFBA'
  AND year = 2025 AND month = 12
GROUP BY referral_level
ORDER BY referral_level;

-- 6. サイクル計算確認
-- cum_usdt >= 2200 でNFT自動付与されるべき
SELECT '=== 6. サイクル計算確認 ===' as section;
SELECT
  cum_usdt,
  CASE
    WHEN cum_usdt >= 2200 THEN 'NFT自動付与対象！'
    WHEN cum_usdt >= 1100 THEN 'HOLDフェーズ'
    ELSE 'USDTフェーズ'
  END as status,
  FLOOR(cum_usdt / 1100) as cycle_position,
  cum_usdt - (FLOOR(cum_usdt / 2200) * 2200) as remaining_after_nft
FROM affiliate_cycle
WHERE user_id = 'ACBFBA';

-- 7. 購入履歴
SELECT '=== 7. 購入履歴 ===' as section;
SELECT
  id,
  amount_usd,
  is_auto_purchase,
  cycle_number_at_purchase,
  admin_approved,
  created_at
FROM purchases
WHERE user_id = 'ACBFBA'
ORDER BY created_at;
