-- ========================================
-- NFT重複・不整合の修正
-- 対象: CA7902, 0E0171, 3194C4, 4CE189, 794682
-- 実行日: 2025-12-23
-- ========================================

-- ★★★ 修正前の確認 ★★★
SELECT 'BEFORE FIX' as status;
SELECT
  u.user_id,
  u.email,
  u.total_purchases,
  u.has_approved_nft,
  u.is_active_investor,
  ac.manual_nft_count,
  ac.total_nft_count,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = u.user_id AND buyback_date IS NULL) as active_nft_count
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.user_id IN ('CA7902', '0E0171', '3194C4', '4CE189', '794682');

-- ========================================
-- 1. CA7902: 重複NFT削除（2枚→1枚）
-- ========================================
DELETE FROM nft_master
WHERE id = '6897fc24-307a-40d1-920b-40a507b8f69e'
  AND user_id = 'CA7902';

-- total_purchasesが2200なら1100に修正
UPDATE users
SET total_purchases = 1100
WHERE user_id = 'CA7902'
  AND total_purchases > 1100;

-- ========================================
-- 2. 0E0171: 重複NFT削除（2枚→1枚）
-- ========================================
DELETE FROM nft_master
WHERE id = '720428a0-9f26-4d63-ac3a-35c713e15a0c'
  AND user_id = '0E0171';

-- total_purchasesを修正（2200→1100）
UPDATE users
SET total_purchases = 1100
WHERE user_id = '0E0171';

-- affiliate_cycleを修正（2→1）
UPDATE affiliate_cycle
SET
  manual_nft_count = 1,
  total_nft_count = 1
WHERE user_id = '0E0171';

-- ========================================
-- 3. 3194C4: 解約済みなのでtotal_purchases=0に
-- 紹介報酬は会社アカウント(7A9637)に入る設定済み
-- ========================================
UPDATE users
SET
  total_purchases = 0,
  has_approved_nft = false,
  is_active_investor = false
WHERE user_id = '3194C4';

-- ========================================
-- 4. 4CE189: テストアカウント削除
-- ========================================
-- まずaffiliate_cycleを削除
DELETE FROM affiliate_cycle WHERE user_id = '4CE189';

-- nft_masterを削除
DELETE FROM nft_master WHERE user_id = '4CE189';

-- purchasesを削除（あれば）
DELETE FROM purchases WHERE user_id = '4CE189';

-- usersを削除
DELETE FROM users WHERE user_id = '4CE189';

-- ========================================
-- 5. 794682: 投資記録なしなのにNFT1枚ある
-- NFTを削除し、is_active_investor=falseに
-- ========================================
-- affiliate_cycleを修正
UPDATE affiliate_cycle
SET
  manual_nft_count = 0,
  total_nft_count = 0
WHERE user_id = '794682';

-- nft_masterからNFTを削除
DELETE FROM nft_master
WHERE user_id = '794682';

-- usersを修正
UPDATE users
SET
  has_approved_nft = false,
  is_active_investor = false
WHERE user_id = '794682';

-- ★★★ 修正後の確認 ★★★
SELECT 'AFTER FIX' as status;
SELECT
  u.user_id,
  u.email,
  u.total_purchases,
  u.has_approved_nft,
  u.is_active_investor,
  ac.manual_nft_count,
  ac.total_nft_count,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = u.user_id AND buyback_date IS NULL) as active_nft_count
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.user_id IN ('CA7902', '0E0171', '3194C4', '794682');

-- 4CE189は削除されたので確認
SELECT '4CE189 deleted check' as status;
SELECT EXISTS(SELECT 1 FROM users WHERE user_id = '4CE189') as still_exists;
