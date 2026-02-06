-- ========================================
-- 177B83の紹介報酬履歴詳細
-- ========================================

-- 全紹介報酬レコード
SELECT '=== 全紹介報酬レコード ===' as section;
SELECT 
  year_month,
  referral_level,
  child_user_id,
  profit_amount
FROM monthly_referral_profit
WHERE user_id = '177B83'
ORDER BY year_month, referral_level;

-- 月別・レベル別集計
SELECT '=== 月別・レベル別集計 ===' as section;
SELECT 
  year_month,
  referral_level,
  COUNT(*) as 件数,
  SUM(profit_amount) as 紹介報酬
FROM monthly_referral_profit
WHERE user_id = '177B83'
GROUP BY year_month, referral_level
ORDER BY year_month, referral_level;

-- 月別累計
SELECT '=== 月別累計 ===' as section;
SELECT 
  year_month,
  SUM(profit_amount) as 月間紹介報酬,
  SUM(SUM(profit_amount)) OVER (ORDER BY year_month) as 累計
FROM monthly_referral_profit
WHERE user_id = '177B83'
GROUP BY year_month
ORDER BY year_month;
