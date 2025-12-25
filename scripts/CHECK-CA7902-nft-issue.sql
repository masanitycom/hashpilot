-- ========================================
-- CA7902 ユーザーのNFT/運用金額調査
-- 問題: NFT1枚なのに2000ドルで運用されている
-- ========================================

-- 1. 基本情報
SELECT
  user_id,
  email,
  full_name,
  total_purchases,
  has_approved_nft,
  operation_start_date,
  is_active_investor,
  created_at
FROM users
WHERE user_id = 'CA7902';

-- 2. NFT保有状況
SELECT
  id,
  user_id,
  nft_type,
  acquired_date,
  buyback_date,
  is_active
FROM nft_master
WHERE user_id = 'CA7902'
ORDER BY acquired_date;

-- 3. 購入履歴
SELECT
  id,
  user_id,
  amount_usd,
  nft_quantity,
  admin_approved,
  is_auto_purchase,
  created_at,
  updated_at
FROM purchases
WHERE user_id = 'CA7902'
ORDER BY created_at;

-- 4. 日利配布履歴（最新10件）
SELECT
  profit_date,
  nft_count,
  profit_per_nft,
  total_profit
FROM nft_daily_profit
WHERE user_id = 'CA7902'
ORDER BY profit_date DESC
LIMIT 10;

-- 5. affiliate_cycle
SELECT *
FROM affiliate_cycle
WHERE user_id = 'CA7902';
