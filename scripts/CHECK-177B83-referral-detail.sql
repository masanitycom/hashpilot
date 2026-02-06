-- ========================================
-- 177B83 紹介報酬詳細確認
-- ========================================

-- 1. 月別紹介報酬
SELECT '=== 月別紹介報酬 ===' as section;
SELECT 
  year_month,
  profit_amount,
  created_at
FROM monthly_referral_profit
WHERE user_id = '177B83'
ORDER BY year_month;

-- 2. affiliate_cycle現状
SELECT '=== affiliate_cycle現状 ===' as section;
SELECT 
  user_id,
  cum_usdt,
  available_usdt,
  withdrawn_referral_usdt,
  phase,
  auto_nft_count,
  manual_nft_count
FROM affiliate_cycle
WHERE user_id = '177B83';

-- 3. 出金履歴
SELECT '=== 出金履歴 ===' as section;
SELECT 
  withdrawal_month,
  personal_amount,
  referral_amount,
  total_amount,
  status
FROM monthly_withdrawals
WHERE user_id = '177B83'
ORDER BY withdrawal_month;

-- 4. 日利合計（1月）
SELECT '=== 1月日利合計 ===' as section;
SELECT 
  SUM(daily_profit) as jan_daily_profit
FROM nft_daily_profit
WHERE user_id = '177B83'
  AND date >= '2026-01-01' AND date <= '2026-01-31';

-- 5. 紹介報酬合計
SELECT '=== 紹介報酬合計 ===' as section;
SELECT 
  SUM(profit_amount) as total_referral
FROM monthly_referral_profit
WHERE user_id = '177B83';
