-- ========================================
-- 不正な自動NFT（日次処理で誤付与）を修正
-- 対象: 59C23C（1/9に誤って自動NFT付与）
-- 実行日: 2026-01-13
-- ========================================

-- STEP 1: 修正前の状態確認
SELECT '=== STEP 1: 修正前の状態 ===' as section;

SELECT
  nm.id,
  nm.user_id,
  nm.nft_type,
  nm.nft_sequence,
  nm.acquired_date,
  nm.created_at
FROM nft_master nm
WHERE nm.user_id = '59C23C'
ORDER BY nm.acquired_date;

SELECT
  user_id,
  cum_usdt,
  auto_nft_count,
  manual_nft_count,
  total_nft_count,
  phase
FROM affiliate_cycle
WHERE user_id = '59C23C';

-- STEP 2: 不正なNFTを削除（59C23Cの1/9付与分）
SELECT '=== STEP 2: 不正なNFT削除 ===' as section;

DELETE FROM nft_master
WHERE id = '073206f3-17f1-447c-bec3-03483a93a52e';

-- STEP 3: 関連するpurchasesレコードを削除（存在する場合）
SELECT '=== STEP 3: 関連purchases削除 ===' as section;

DELETE FROM purchases
WHERE user_id = '59C23C'
  AND nft_type = 'auto'
  AND purchase_date = '2026-01-09';

-- STEP 4: affiliate_cycleを正しく再計算
SELECT '=== STEP 4: affiliate_cycle修正 ===' as section;

-- 紹介報酬累計: $2477.40
-- 正しい自動NFT数: 1（1/1付与分のみ）
-- cum_usdt = 紹介報酬累計 - (自動NFT数 × 1100) = 2477.40 - 1100 = 1377.40
UPDATE affiliate_cycle
SET
  cum_usdt = 2477.40 - 1100,
  auto_nft_count = 1,
  total_nft_count = manual_nft_count + 1,
  phase = 'HOLD',  -- 1377.40は1100以上なのでHOLD
  updated_at = NOW()
WHERE user_id = '59C23C';

-- STEP 5: 修正後の確認
SELECT '=== STEP 5: 修正後の状態 ===' as section;

SELECT
  nm.id,
  nm.user_id,
  nm.nft_type,
  nm.nft_sequence,
  nm.acquired_date
FROM nft_master nm
WHERE nm.user_id = '59C23C'
ORDER BY nm.acquired_date;

SELECT
  user_id,
  cum_usdt,
  auto_nft_count,
  manual_nft_count,
  total_nft_count,
  phase
FROM affiliate_cycle
WHERE user_id = '59C23C';

-- 完了
DO $$
BEGIN
  RAISE NOTICE '59C23Cの不正な自動NFT修正完了';
  RAISE NOTICE 'cum_usdt: 2477.40 -> 1377.40';
  RAISE NOTICE 'auto_nft_count: 維持 1';
  RAISE NOTICE 'phase: HOLD（1100以上のため）';
END $$;
