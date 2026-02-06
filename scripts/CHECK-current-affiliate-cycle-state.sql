-- 現在のaffiliate_cycleの状態を確認
SELECT '=== 177B83と59C23Cの状態 ===' as section;
SELECT
  user_id,
  ROUND(available_usdt::numeric, 2) as "available_usdt(日利)",
  ROUND(cum_usdt::numeric, 2) as "cum_usdt(紹介報酬)",
  phase,
  ROUND(COALESCE(withdrawn_referral_usdt, 0)::numeric, 2) as "withdrawn_referral",
  auto_nft_count
FROM affiliate_cycle
WHERE user_id IN ('177B83', '59C23C');

-- HOLDになっているユーザー数
SELECT '=== フェーズ別ユーザー数 ===' as section;
SELECT 
  phase,
  COUNT(*) as user_count,
  ROUND(SUM(cum_usdt)::numeric, 2) as total_cum_usdt
FROM affiliate_cycle
GROUP BY phase;

-- pending出金レコードの確認
SELECT '=== 1月分pending出金（177B83, 59C23C）===' as section;
SELECT
  user_id,
  personal_amount,
  referral_amount,
  total_amount,
  status,
  created_at::date
FROM monthly_withdrawals
WHERE user_id IN ('177B83', '59C23C')
  AND withdrawal_month = '2026-01-01';
