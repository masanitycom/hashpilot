-- ========================================
-- 177B83の月別紹介報酬
-- ========================================

SELECT '=== 月別紹介報酬 ===' as section;
SELECT 
  year_month,
  SUM(profit_amount) as 紹介報酬
FROM monthly_referral_profit
WHERE user_id = '177B83'
GROUP BY year_month
ORDER BY year_month;

-- 12月末時点のcum_usdt（NFT自動付与判定用）
SELECT '=== 12月末時点のcum_usdt ===' as section;
SELECT 
  SUM(profit_amount) as 紹介報酬累計_12月まで
FROM monthly_referral_profit
WHERE user_id = '177B83'
  AND year_month <= '2025-12';

-- NFT自動付与が必要な全ユーザー
SELECT '=== NFT自動付与未実施ユーザー ===' as section;
SELECT 
  ac.user_id,
  ac.cum_usdt,
  ac.auto_nft_count,
  FLOOR(ac.cum_usdt / 2200)::int as 本来のauto_nft_count,
  ac.phase
FROM affiliate_cycle ac
WHERE ac.cum_usdt >= 2200
  AND ac.auto_nft_count < FLOOR(ac.cum_usdt / 2200)::int
ORDER BY ac.cum_usdt DESC;
