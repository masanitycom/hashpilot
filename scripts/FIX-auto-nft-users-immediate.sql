-- ========================================
-- 自動購入NFTユーザーの即時修正
-- ========================================
-- 対象: 59C23C, 177B83
-- 問題: cum_usdtから$1,100しか引かれていない（本来$2,200）
-- ========================================

-- STEP 1: 修正前の確認
SELECT '=== 修正前 ===' as section;
SELECT
  user_id,
  cum_usdt as "現在cum_usdt",
  phase as "現在phase",
  auto_nft_count
FROM affiliate_cycle
WHERE user_id IN ('59C23C', '177B83');

-- STEP 2: cum_usdtとphaseを修正
-- 正しいcum_usdt = 紹介報酬累計 - (auto_nft_count × 2200)

-- 59C23C: $3,026.86 - $2,200 = $826.86 (USDT)
UPDATE affiliate_cycle
SET
  cum_usdt = 826.86,
  phase = 'USDT',
  updated_at = NOW()
WHERE user_id = '59C23C';

-- 177B83: $2,290.52 - $2,200 = $90.52 (USDT)
UPDATE affiliate_cycle
SET
  cum_usdt = 90.52,
  phase = 'USDT',
  updated_at = NOW()
WHERE user_id = '177B83';

-- STEP 3: 修正後の確認
SELECT '=== 修正後 ===' as section;
SELECT
  user_id,
  cum_usdt as "修正後cum_usdt",
  phase as "修正後phase",
  auto_nft_count
FROM affiliate_cycle
WHERE user_id IN ('59C23C', '177B83');

SELECT '✅ 59C23C, 177B83のcum_usdtとphaseを修正しました' as status;
