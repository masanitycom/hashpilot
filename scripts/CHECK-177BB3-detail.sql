-- ========================================
-- 177BB3の詳細確認
-- ========================================

-- 1. affiliate_cycleの状態
SELECT '=== affiliate_cycle ===' as section;
SELECT 
  user_id,
  cum_usdt,
  available_usdt,
  withdrawn_referral_usdt,
  phase,
  auto_nft_count,
  manual_nft_count,
  total_nft_count
FROM affiliate_cycle
WHERE user_id = '177BB3';

-- 2. NFT保有状況
SELECT '=== nft_master ===' as section;
SELECT 
  user_id,
  nft_sequence,
  nft_type,
  acquired_date,
  operation_start_date,
  buyback_date
FROM nft_master
WHERE user_id = '177BB3'
ORDER BY nft_sequence;

-- 3. 全期間の紹介報酬累計
SELECT '=== 紹介報酬累計 ===' as section;
SELECT 
  user_id,
  SUM(profit_amount) as 紹介報酬累計
FROM monthly_referral_profit
WHERE user_id = '177BB3'
GROUP BY user_id;

-- 4. 過去の出金履歴
SELECT '=== 出金履歴 ===' as section;
SELECT 
  user_id,
  withdrawal_month,
  total_amount,
  personal_amount,
  referral_amount,
  status
FROM monthly_withdrawals
WHERE user_id = '177BB3'
ORDER BY withdrawal_month;
