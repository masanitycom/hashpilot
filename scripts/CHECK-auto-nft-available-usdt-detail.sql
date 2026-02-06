-- ========================================
-- 自動NFTユーザーのavailable_usdt詳細調査
-- ========================================

-- 59C23Cの詳細
SELECT '=== 59C23C 詳細 ===' as section;

-- 紹介報酬の月別内訳
SELECT 
  year_month,
  SUM(profit_amount) as referral_amount
FROM monthly_referral_profit
WHERE user_id = '59C23C'
GROUP BY year_month
ORDER BY year_month;

-- 日利の月別内訳
SELECT 
  to_char(date, 'YYYY-MM') as year_month,
  SUM(daily_profit) as daily_profit
FROM nft_daily_profit
WHERE user_id = '59C23C'
GROUP BY to_char(date, 'YYYY-MM')
ORDER BY year_month;

-- 出金履歴
SELECT 
  to_char(year_month, 'YYYY-MM') as month,
  personal_amount,
  referral_amount,
  total_amount,
  status
FROM monthly_withdrawals
WHERE user_id = '59C23C'
ORDER BY year_month;

-- 177B83の詳細
SELECT '=== 177B83 詳細 ===' as section;

-- 紹介報酬の月別内訳
SELECT 
  year_month,
  SUM(profit_amount) as referral_amount
FROM monthly_referral_profit
WHERE user_id = '177B83'
GROUP BY year_month
ORDER BY year_month;

-- 出金履歴
SELECT 
  to_char(year_month, 'YYYY-MM') as month,
  personal_amount,
  referral_amount,
  total_amount,
  status
FROM monthly_withdrawals
WHERE user_id = '177B83'
ORDER BY year_month;

-- 問題の仮説検証
SELECT '=== 差分の内訳分析 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as "available_usdt",
  ROUND((COALESCE(dp.total, 0) - COALESCE(w.personal, 0))::numeric, 2) as "理論値(日利-出金)",
  ROUND((ac.available_usdt - (COALESCE(dp.total, 0) - COALESCE(w.personal, 0)))::numeric, 2) as "差分",
  ROUND(COALESCE(rp.total_referral, 0)::numeric, 2) as "紹介報酬累計",
  ac.auto_nft_count,
  -- 仮説: 差分 = 紹介報酬のHOLD分が引かれている？
  ROUND((COALESCE(rp.total_referral, 0) - (ac.auto_nft_count * 1100))::numeric, 2) as "紹介報酬-NFT購入",
  -- 仮説: 差分 = 何らかの紹介報酬分？
  ROUND((ac.available_usdt - (COALESCE(dp.total, 0) - COALESCE(w.personal, 0)) + COALESCE(rp.total_referral, 0) - ac.cum_usdt - COALESCE(w.referral, 0))::numeric, 2) as "検証値"
FROM affiliate_cycle ac
LEFT JOIN (SELECT user_id, SUM(daily_profit) as total FROM nft_daily_profit GROUP BY user_id) dp ON ac.user_id = dp.user_id
LEFT JOIN (SELECT user_id, SUM(profit_amount) as total_referral FROM monthly_referral_profit GROUP BY user_id) rp ON ac.user_id = rp.user_id
LEFT JOIN (
  SELECT user_id, 
    SUM(COALESCE(personal_amount, total_amount)) as personal,
    SUM(COALESCE(referral_amount, 0)) as referral
  FROM monthly_withdrawals WHERE status = 'completed' GROUP BY user_id
) w ON ac.user_id = w.user_id
WHERE ac.user_id IN ('59C23C', '177B83', '5FAE2C', '07712F');
