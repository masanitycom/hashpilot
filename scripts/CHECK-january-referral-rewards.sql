-- ========================================
-- 1月の紹介報酬確認
-- ========================================

-- 1. monthly_referral_profitの月別統計
SELECT '=== 1. 月別紹介報酬統計 ===' as section;
SELECT
  year_month,
  COUNT(DISTINCT user_id) as user_count,
  COUNT(*) as records,
  ROUND(SUM(profit_amount)::numeric, 2) as total_profit
FROM monthly_referral_profit
GROUP BY year_month
ORDER BY year_month;

-- 2. 1月分のpending出金でreferral_amount = 0のユーザー
SELECT '=== 2. 1月pending出金でreferral=0 ===' as section;
SELECT
  COUNT(*) as "referral=0のユーザー数",
  COUNT(*) FILTER (WHERE referral_amount > 0) as "referral>0のユーザー数"
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01'
  AND status IN ('pending', 'on_hold');

-- 3. cum_usdtの状態
SELECT '=== 3. cum_usdtの分布 ===' as section;
SELECT
  CASE
    WHEN cum_usdt = 0 THEN 'cum_usdt = 0'
    WHEN cum_usdt > 0 AND cum_usdt < 1100 THEN 'USDT (0-1100)'
    WHEN cum_usdt >= 1100 THEN 'HOLD (1100+)'
    ELSE 'マイナス'
  END as category,
  COUNT(*) as user_count,
  ROUND(SUM(cum_usdt)::numeric, 2) as total_cum
FROM affiliate_cycle
GROUP BY 1
ORDER BY 1;

-- 4. 紹介報酬があるはずなのにcum_usdt=0のユーザー
SELECT '=== 4. 紹介報酬あり但しcum_usdt=0 ===' as section;
SELECT
  mrp.user_id,
  ROUND(SUM(mrp.profit_amount)::numeric, 2) as "紹介報酬合計",
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt"
FROM monthly_referral_profit mrp
JOIN affiliate_cycle ac ON mrp.user_id = ac.user_id
GROUP BY mrp.user_id, ac.cum_usdt
HAVING ac.cum_usdt = 0 AND SUM(mrp.profit_amount) > 0
ORDER BY SUM(mrp.profit_amount) DESC
LIMIT 20;

-- 5. process_monthly_referral_rewardが1月に実行されたか
SELECT '=== 5. 1月の紹介報酬レコード ===' as section;
SELECT
  user_id,
  year_month,
  referral_level,
  ROUND(profit_amount::numeric, 2) as profit
FROM monthly_referral_profit
WHERE year_month = '2026-01'
ORDER BY profit_amount DESC
LIMIT 20;

-- 6. 11月・12月との比較
SELECT '=== 6. 月別紹介報酬詳細 ===' as section;
SELECT
  year_month,
  referral_level,
  COUNT(DISTINCT user_id) as users,
  ROUND(SUM(profit_amount)::numeric, 2) as total
FROM monthly_referral_profit
GROUP BY year_month, referral_level
ORDER BY year_month, referral_level;
