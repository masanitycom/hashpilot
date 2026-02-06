-- ========================================
-- cum_usdtとmonthly_referral_profitの比較
-- ========================================

-- 1. monthly_referral_profitの合計 vs cum_usdtの比較
SELECT '=== 1. cum_usdt vs 紹介報酬合計 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt",
  ROUND(COALESCE(mrp.total_referral, 0)::numeric, 2) as "紹介報酬合計",
  ROUND((COALESCE(mrp.total_referral, 0) - ac.cum_usdt)::numeric, 2) as "差分"
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ABS(COALESCE(mrp.total_referral, 0) - ac.cum_usdt) > 0.01
ORDER BY ABS(COALESCE(mrp.total_referral, 0) - ac.cum_usdt) DESC
LIMIT 30;

-- 2. 不一致の統計
SELECT '=== 2. 不一致の統計 ===' as section;
SELECT
  COUNT(*) as "不一致ユーザー数",
  COUNT(*) FILTER (WHERE ac.cum_usdt = 0 AND COALESCE(mrp.total_referral, 0) > 0) as "cum_usdt=0だが報酬あり",
  COUNT(*) FILTER (WHERE ac.cum_usdt > 0 AND COALESCE(mrp.total_referral, 0) = 0) as "cum_usdt>0だが報酬なし"
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ABS(COALESCE(mrp.total_referral, 0) - ac.cum_usdt) > 0.01;

-- 3. 177B83と59C23Cの詳細
SELECT '=== 3. 177B83と59C23Cの詳細 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt",
  ROUND(ac.available_usdt::numeric, 2) as "available_usdt",
  ac.phase,
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as "withdrawn_referral"
FROM affiliate_cycle ac
WHERE ac.user_id IN ('177B83', '59C23C');

-- 4. 177B83の紹介報酬詳細
SELECT '=== 4. 177B83の月別紹介報酬 ===' as section;
SELECT
  year_month,
  referral_level,
  COUNT(*) as records,
  ROUND(SUM(profit_amount)::numeric, 2) as total
FROM monthly_referral_profit
WHERE user_id = '177B83'
GROUP BY year_month, referral_level
ORDER BY year_month, referral_level;

-- 5. 59C23Cの紹介報酬詳細
SELECT '=== 5. 59C23Cの月別紹介報酬 ===' as section;
SELECT
  year_month,
  referral_level,
  COUNT(*) as records,
  ROUND(SUM(profit_amount)::numeric, 2) as total
FROM monthly_referral_profit
WHERE user_id = '59C23C'
GROUP BY year_month, referral_level
ORDER BY year_month, referral_level;

-- 6. NFT自動購入の履歴
SELECT '=== 6. NFT自動購入履歴 ===' as section;
SELECT
  user_id,
  COUNT(*) as auto_nft_count,
  SUM(amount_usd) as total_spent
FROM purchases
WHERE is_auto_purchase = true
GROUP BY user_id
ORDER BY COUNT(*) DESC
LIMIT 10;
