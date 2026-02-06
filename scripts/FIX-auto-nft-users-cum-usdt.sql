-- ========================================
-- NFT自動付与ユーザーのcum_usdt修正
-- ========================================
-- 問題: cum_usdtを紹介報酬累計で上書きしたため、
--       NFT自動付与の$1,100減算がリセットされた
-- 修正: cum_usdt = 紹介報酬累計 - (auto_nft_count × 1100)
-- ========================================

-- STEP 1: 修正前の状態確認（NFT自動付与ユーザー）
SELECT '=== STEP 1: 修正前の状態 ===' as section;
SELECT 
  ac.user_id,
  ac.auto_nft_count,
  ac.cum_usdt as 現在のcum_usdt,
  COALESCE(mrp.total_referral, 0) as 紹介報酬累計,
  COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 1100) as 正しいcum_usdt,
  ac.cum_usdt - (COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 1100)) as 差額,
  ac.phase
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ac.auto_nft_count > 0
ORDER BY ac.auto_nft_count DESC, ac.cum_usdt DESC;

-- STEP 2: cum_usdtを修正
SELECT '=== STEP 2: cum_usdtを修正 ===' as section;
UPDATE affiliate_cycle ac
SET 
  cum_usdt = COALESCE(mrp.total_referral, 0) - (ac.auto_nft_count * 1100),
  updated_at = NOW()
FROM (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp
WHERE ac.user_id = mrp.user_id
  AND ac.auto_nft_count > 0;

-- STEP 3: phaseを再計算
SELECT '=== STEP 3: phaseを再計算 ===' as section;
UPDATE affiliate_cycle
SET 
  phase = CASE 
    WHEN cum_usdt < 1100 THEN 'USDT'
    WHEN (FLOOR(cum_usdt / 1100)::int % 2) = 0 THEN 'USDT'
    ELSE 'HOLD'
  END,
  updated_at = NOW()
WHERE auto_nft_count > 0;

-- STEP 4: 修正後の状態確認
SELECT '=== STEP 4: 修正後の状態 ===' as section;
SELECT 
  ac.user_id,
  ac.auto_nft_count,
  ac.cum_usdt as 修正後のcum_usdt,
  COALESCE(mrp.total_referral, 0) as 紹介報酬累計,
  ac.phase
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ac.auto_nft_count > 0
ORDER BY ac.auto_nft_count DESC, ac.cum_usdt DESC;

-- STEP 5: 59C23Cの確認
SELECT '=== STEP 5: 59C23C確認 ===' as section;
SELECT 
  user_id,
  cum_usdt,
  available_usdt,
  withdrawn_referral_usdt,
  phase,
  auto_nft_count
FROM affiliate_cycle
WHERE user_id = '59C23C';
