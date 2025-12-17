-- 3194C4ユーザーの休眠状態確認
-- 実行日: 2025-12-12

-- ========================================
-- 1. ユーザー基本情報
-- ========================================
SELECT
  '1. ユーザー基本情報' as section,
  u.user_id,
  u.email,
  u.is_active_investor,
  u.has_approved_nft,
  u.operation_start_date,
  u.created_at
FROM users u
WHERE u.user_id = '3194C4';

-- ========================================
-- 2. NFT保有状況
-- ========================================
SELECT
  '2. NFT保有状況' as section,
  COUNT(*) as total_nft_records,
  COUNT(CASE WHEN buyback_date IS NULL THEN 1 END) as active_nfts,
  COUNT(CASE WHEN buyback_date IS NOT NULL THEN 1 END) as bought_back_nfts
FROM nft_master
WHERE user_id = '3194C4';

-- 買い取られたNFTの詳細
SELECT
  '2b. 買い取りNFT詳細' as section,
  id,
  nft_type,
  acquired_date,
  buyback_date
FROM nft_master
WHERE user_id = '3194C4'
ORDER BY acquired_date;

-- ========================================
-- 3. affiliate_cycle状態
-- ========================================
SELECT
  '3. affiliate_cycle状態' as section,
  user_id,
  total_nft_count,
  manual_nft_count,
  auto_nft_count,
  cum_usdt,
  available_usdt,
  phase
FROM affiliate_cycle
WHERE user_id = '3194C4';

-- ========================================
-- 4. 紹介ツリー確認（このユーザーの下位ユーザー）
-- ========================================
SELECT
  '4. 下位ユーザー（直接紹介）' as section,
  user_id,
  email,
  is_active_investor,
  total_purchases
FROM users
WHERE referrer_user_id = '3194C4';

-- ========================================
-- 5. 会社ボーナス確認（このユーザーが休眠になってから）
-- ========================================
SELECT
  '5. 会社が代わりに受け取った報酬' as section,
  date,
  dormant_user_id,
  child_user_id,
  referral_level,
  original_amount
FROM company_bonus_from_dormant
WHERE dormant_user_id = '3194C4'
ORDER BY date DESC
LIMIT 20;

-- 会社ボーナス合計
SELECT
  '5b. 会社ボーナス合計' as section,
  COUNT(*) as record_count,
  SUM(original_amount) as total_company_bonus
FROM company_bonus_from_dormant
WHERE dormant_user_id = '3194C4';

-- ========================================
-- 6. 買い取り申請履歴
-- ========================================
SELECT
  '6. 買い取り申請履歴' as section,
  id,
  request_date,
  manual_nft_count,
  auto_nft_count,
  total_buyback_amount,
  status,
  processed_at
FROM buyback_requests
WHERE user_id = '3194C4'
ORDER BY request_date DESC;
