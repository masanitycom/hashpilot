-- ========================================
-- NFTサイクル修正（月末処理のみ）
-- ========================================
-- 問題: process_monthly_referral_rewardでNFT自動付与時に
--       cum_usdtから$1,100しか引いていない
-- 正しい: $2,200を引く（$1,100 NFT代 + $1,100 HOLD解放）
-- ========================================
-- 影響ユーザー: 177B83, 59C23C（自動NFT付与済み）
-- ========================================

-- ========================================
-- STEP 0: 現状確認
-- ========================================
SELECT '=== STEP 0: 修正前の状態確認 ===' as section;

SELECT
  ac.user_id,
  ac.auto_nft_count as "自動NFT数",
  ac.cum_usdt as "現在cum_usdt",
  ac.phase as "現在phase",
  ac.available_usdt as "available_usdt",
  COALESCE(mrp.total_referral, 0) as "紹介報酬累計",
  -- 正しいcum_usdt = 紹介報酬累計 - (NFT数 × 2200)
  COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200) as "正しいcum_usdt",
  CASE
    WHEN (COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200)) >= 1100 THEN 'HOLD'
    ELSE 'USDT'
  END as "正しいphase"
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ac.auto_nft_count > 0
ORDER BY ac.user_id;

-- ========================================
-- STEP 1: 既存ユーザーの手動修正
-- ========================================
-- 正しいcum_usdt = 紹介報酬累計 - (auto_nft_count × 2200)
-- ========================================
SELECT '=== STEP 1: 既存ユーザーの修正 ===' as section;

UPDATE affiliate_cycle ac
SET
  cum_usdt = GREATEST(0, COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200)),
  phase = CASE
    WHEN GREATEST(0, COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200)) >= 1100 THEN 'HOLD'
    ELSE 'USDT'
  END,
  updated_at = NOW()
FROM (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp
WHERE ac.user_id = mrp.user_id
  AND ac.auto_nft_count > 0;

-- ========================================
-- STEP 2: 修正後の確認
-- ========================================
SELECT '=== STEP 2: 修正後の状態確認 ===' as section;

SELECT
  ac.user_id,
  ac.auto_nft_count as "自動NFT数",
  ac.cum_usdt as "修正後cum_usdt",
  ac.phase as "修正後phase",
  ac.available_usdt as "available_usdt",
  COALESCE(mrp.total_referral, 0) as "紹介報酬累計",
  COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 2200) as "計算値（検証）"
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ac.auto_nft_count > 0
ORDER BY ac.user_id;

SELECT '既存ユーザーの修正完了' as status;
