-- 59C23Cの出金履歴
SELECT 
  id,
  created_at,
  personal_amount,
  referral_amount,
  total_amount,
  status
FROM monthly_withdrawals
WHERE user_id = '59C23C'
ORDER BY created_at;

-- 177B83の出金履歴
SELECT 
  id,
  created_at,
  personal_amount,
  referral_amount,
  total_amount,
  status
FROM monthly_withdrawals
WHERE user_id = '177B83'
ORDER BY created_at;

-- 差分分析（修正版）
SELECT '=== 差分の詳細分析 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as "available_usdt",
  ROUND(COALESCE(dp.total, 0)::numeric, 2) as "日利合計",
  ROUND(COALESCE(w.personal, 0)::numeric, 2) as "出金済み個人",
  ROUND(COALESCE(w.referral, 0)::numeric, 2) as "出金済み紹介",
  ROUND((COALESCE(dp.total, 0) - COALESCE(w.personal, 0))::numeric, 2) as "理論値(日利-個人出金)",
  ROUND((ac.available_usdt - (COALESCE(dp.total, 0) - COALESCE(w.personal, 0)))::numeric, 2) as "差分",
  ac.auto_nft_count,
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt",
  ROUND(COALESCE(rp.total_referral, 0)::numeric, 2) as "紹介報酬累計"
FROM affiliate_cycle ac
LEFT JOIN (SELECT user_id, SUM(daily_profit) as total FROM nft_daily_profit GROUP BY user_id) dp ON ac.user_id = dp.user_id
LEFT JOIN (SELECT user_id, SUM(profit_amount) as total_referral FROM monthly_referral_profit GROUP BY user_id) rp ON ac.user_id = rp.user_id
LEFT JOIN (
  SELECT user_id, 
    SUM(COALESCE(personal_amount, total_amount)) as personal,
    SUM(COALESCE(referral_amount, 0)) as referral
  FROM monthly_withdrawals WHERE status = 'completed' GROUP BY user_id
) w ON ac.user_id = w.user_id
WHERE ac.user_id IN ('59C23C', '177B83');
