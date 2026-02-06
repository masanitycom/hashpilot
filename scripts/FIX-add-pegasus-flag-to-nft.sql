-- ========================================
-- NFTにペガサスフラグを追加
-- ========================================
-- 目的: NFT単位でペガサス交換かどうかを管理
-- ========================================

-- STEP 1: nft_masterにis_pegasusカラムを追加
ALTER TABLE nft_master
ADD COLUMN IF NOT EXISTS is_pegasus BOOLEAN DEFAULT false;

COMMENT ON COLUMN nft_master.is_pegasus IS 'ペガサス交換によるNFTかどうか（trueの場合、日利対象外）';

-- STEP 2: F511A4の1枚目のNFTをペガサスとしてマーク
UPDATE nft_master
SET is_pegasus = true
WHERE user_id = 'F511A4'
  AND nft_sequence = 1;

-- STEP 3: 確認
SELECT '=== F511A4のNFT状態 ===' as section;
SELECT
  nft_sequence,
  nft_type,
  acquired_date,
  operation_start_date,
  is_pegasus
FROM nft_master
WHERE user_id = 'F511A4'
ORDER BY nft_sequence;

-- STEP 4: 他のペガサスユーザーのNFTも確認（必要に応じてマーク）
SELECT '=== ペガサスユーザーのNFT一覧 ===' as section;
SELECT
  u.user_id,
  u.email,
  nm.nft_sequence,
  nm.acquired_date,
  nm.operation_start_date,
  nm.is_pegasus
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id
WHERE u.is_pegasus_exchange = true
  AND nm.buyback_date IS NULL
ORDER BY u.user_id, nm.nft_sequence;
