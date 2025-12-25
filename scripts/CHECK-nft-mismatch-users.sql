-- ========================================
-- NFT枚数不整合ユーザーの詳細調査
-- 0E0171, 4CE189, 794682, 3194C4, CA7902
-- ========================================

-- 1. 全ユーザーの基本情報
SELECT
  user_id,
  email,
  full_name,
  total_purchases,
  has_approved_nft,
  operation_start_date,
  created_at
FROM users
WHERE user_id IN ('0E0171', '4CE189', '794682', '3194C4', 'CA7902')
ORDER BY user_id;

-- 2. 各ユーザーのNFT詳細（created_atで作成タイミングを確認）
SELECT
  user_id,
  id as nft_id,
  nft_sequence,
  nft_type,
  acquired_date,
  created_at,
  buyback_date
FROM nft_master
WHERE user_id IN ('0E0171', '4CE189', '794682', '3194C4', 'CA7902')
ORDER BY user_id, created_at;

-- 3. 各ユーザーの購入履歴
SELECT
  user_id,
  id as purchase_id,
  amount_usd,
  nft_quantity,
  admin_approved,
  admin_approved_at,
  admin_approved_by,
  is_auto_purchase,
  created_at
FROM purchases
WHERE user_id IN ('0E0171', '4CE189', '794682', '3194C4', 'CA7902')
ORDER BY user_id, created_at;

-- 4. affiliate_cycleの状態
SELECT
  user_id,
  manual_nft_count,
  auto_nft_count,
  total_nft_count,
  cum_usdt,
  available_usdt,
  phase
FROM affiliate_cycle
WHERE user_id IN ('0E0171', '4CE189', '794682', '3194C4', 'CA7902')
ORDER BY user_id;
