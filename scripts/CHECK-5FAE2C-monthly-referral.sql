-- 5FAE2Cの月別紹介報酬確認

-- 1. 月別紹介報酬
SELECT '=== 月別紹介報酬 ===' as section;
SELECT
  year_month,
  SUM(profit_amount) as 紹介報酬
FROM monthly_referral_profit
WHERE user_id = '5FAE2C'
GROUP BY year_month
ORDER BY year_month;

-- 2. 累計計算
SELECT '=== 累計確認 ===' as section;

-- 11月まで
SELECT '11月まで' as 期間, SUM(profit_amount) as 累計
FROM monthly_referral_profit
WHERE user_id = '5FAE2C' AND year_month <= '2025-11';

-- 12月まで
SELECT '12月まで' as 期間, SUM(profit_amount) as 累計
FROM monthly_referral_profit
WHERE user_id = '5FAE2C' AND year_month <= '2025-12';

-- 1月まで
SELECT '1月まで' as 期間, SUM(profit_amount) as 累計
FROM monthly_referral_profit
WHERE user_id = '5FAE2C' AND year_month <= '2026-01';

-- 3. affiliate_cycleの現在値
SELECT '=== affiliate_cycle ===' as section;
SELECT
  user_id,
  cum_usdt,
  withdrawn_referral_usdt,
  auto_nft_count,
  phase
FROM affiliate_cycle
WHERE user_id = '5FAE2C';
