-- ========================================
-- 59C23Cのaffiliate_cycleとmonthly_withdrawalsを確認
-- ========================================

-- 1. affiliate_cycleの状態
SELECT '【1】affiliate_cycleの状態' as section;
SELECT
  user_id,
  phase,
  cum_usdt,
  available_usdt,
  withdrawn_referral_usdt,
  auto_nft_count,
  manual_nft_count
FROM affiliate_cycle
WHERE user_id = '59C23C';

-- 2. 11月の出金履歴
SELECT '【2】出金履歴' as section;
SELECT
  user_id,
  withdrawal_month,
  personal_amount,
  referral_amount,
  total_amount,
  status
FROM monthly_withdrawals
WHERE user_id = '59C23C';

-- 3. 月別紹介報酬（monthly_referral_profit）
SELECT '【3】月別紹介報酬' as section;
SELECT
  user_id,
  year_month,
  SUM(profit_amount) as total_referral
FROM monthly_referral_profit
WHERE user_id = '59C23C'
GROUP BY user_id, year_month
ORDER BY year_month;

-- 4. cum_usdtの内訳確認（全期間の紹介報酬合計）
SELECT '【4】全期間の紹介報酬合計' as section;
SELECT
  user_id,
  SUM(profit_amount) as all_time_referral
FROM monthly_referral_profit
WHERE user_id = '59C23C'
GROUP BY user_id;
