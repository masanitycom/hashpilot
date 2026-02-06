-- 177B83の完全データ確認

-- 1. affiliate_cycle
SELECT '=== 1. affiliate_cycle ===' as section;
SELECT
  user_id,
  phase,
  ROUND(cum_usdt::numeric, 2) as cum_usdt,
  ROUND(COALESCE(withdrawn_referral_usdt, 0)::numeric, 2) as withdrawn_referral,
  auto_nft_count
FROM affiliate_cycle
WHERE user_id = '177B83';

-- 2. 月別紹介報酬
SELECT '=== 2. 月別紹介報酬 ===' as section;
SELECT
  year_month,
  ROUND(SUM(profit_amount)::numeric, 2) as total
FROM monthly_referral_profit
WHERE user_id = '177B83'
GROUP BY year_month
ORDER BY year_month;

-- 3. 紹介報酬累計
SELECT '=== 3. 累計 ===' as section;
SELECT ROUND(SUM(profit_amount)::numeric, 2) as "累計" FROM monthly_referral_profit WHERE user_id = '177B83';

-- 4. 全出金履歴
SELECT '=== 4. 全出金履歴 ===' as section;
SELECT
  withdrawal_month,
  status,
  ROUND(personal_amount::numeric, 2) as personal,
  ROUND(COALESCE(referral_amount, 0)::numeric, 2) as referral,
  ROUND(total_amount::numeric, 2) as total
FROM monthly_withdrawals
WHERE user_id = '177B83'
ORDER BY withdrawal_month;

-- 5. 整合性チェック
SELECT '=== 5. 整合性チェック ===' as section;
SELECT
  mrp.total_referral as "累計紹介報酬",
  ac.cum_usdt,
  ac.auto_nft_count,
  (ac.auto_nft_count * 2200) as "NFT購入分",
  ac.withdrawn_referral_usdt,
  mrp.total_referral - (ac.auto_nft_count * 2200) as "累計-NFT購入",
  mrp.total_referral - (ac.auto_nft_count * 2200) - ac.withdrawn_referral_usdt as "理論上の残高"
FROM (
  SELECT SUM(profit_amount) as total_referral FROM monthly_referral_profit WHERE user_id = '177B83'
) mrp,
(
  SELECT cum_usdt, auto_nft_count, COALESCE(withdrawn_referral_usdt, 0) as withdrawn_referral_usdt
  FROM affiliate_cycle WHERE user_id = '177B83'
) ac;
