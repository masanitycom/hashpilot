-- 177B83の全データ確認

-- 1. affiliate_cycle
SELECT '=== 1. affiliate_cycle ===' as section;
SELECT * FROM affiliate_cycle WHERE user_id = '177B83';

-- 2. monthly_referral_profit（月別）
SELECT '=== 2. 月別紹介報酬 ===' as section;
SELECT
  year_month,
  ROUND(SUM(profit_amount)::numeric, 2) as total
FROM monthly_referral_profit
WHERE user_id = '177B83'
GROUP BY year_month
ORDER BY year_month;

-- 3. 紹介報酬累計
SELECT '=== 3. 紹介報酬累計 ===' as section;
SELECT ROUND(SUM(profit_amount)::numeric, 2) as "累計" FROM monthly_referral_profit WHERE user_id = '177B83';

-- 4. monthly_withdrawals（全期間）
SELECT '=== 4. 出金履歴 ===' as section;
SELECT
  withdrawal_month,
  status,
  ROUND(personal_amount::numeric, 2) as personal,
  ROUND(COALESCE(referral_amount, 0)::numeric, 2) as referral,
  ROUND(total_amount::numeric, 2) as total
FROM monthly_withdrawals
WHERE user_id = '177B83'
ORDER BY withdrawal_month;
