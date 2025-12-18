-- ========================================
-- 59C23CのNFT保有状況とサイクル確認
-- ========================================

-- 1. NFT保有状況（手動・自動両方）
SELECT '【1】NFT保有状況' as section;
SELECT
  user_id,
  id as nft_id,
  nft_type,
  acquired_date,
  buyback_date,
  CASE WHEN buyback_date IS NULL THEN 'アクティブ' ELSE '売却済み' END as status
FROM nft_master
WHERE user_id = '59C23C'
ORDER BY acquired_date;

-- 2. 購入履歴
SELECT '【2】購入履歴' as section;
SELECT
  user_id,
  id,
  amount_usd,
  admin_approved,
  is_auto_purchase,
  created_at
FROM purchases
WHERE user_id = '59C23C'
ORDER BY created_at;

-- 3. affiliate_cycleの確認
SELECT '【3】affiliate_cycle' as section;
SELECT
  user_id,
  phase,
  cum_usdt,
  available_usdt,
  withdrawn_referral_usdt,
  auto_nft_count,
  manual_nft_count
FROM affiliate_cycle
WHERE user_id = '59C23C';
