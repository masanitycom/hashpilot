-- ========================================
-- NFT自動付与ユーザーの状態確認
-- 59C23C, 177BB3
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
WHERE user_id IN ('59C23C', '177BB3');

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
WHERE user_id IN ('59C23C', '177BB3')
ORDER BY user_id, nft_sequence;

-- 3. 1月の紹介報酬
SELECT '=== 1月紹介報酬 ===' as section;
SELECT 
  user_id,
  SUM(profit_amount) as 紹介報酬合計,
  COUNT(*) as 件数
FROM monthly_referral_profit
WHERE user_id IN ('59C23C', '177BB3')
  AND year_month = '2026-01'
GROUP BY user_id;

-- 4. 全期間の紹介報酬累計
SELECT '=== 全期間紹介報酬累計 ===' as section;
SELECT 
  user_id,
  SUM(profit_amount) as 紹介報酬累計,
  COUNT(*) as 件数
FROM monthly_referral_profit
WHERE user_id IN ('59C23C', '177BB3')
GROUP BY user_id;

-- 5. 1月の個人利益（日利）
SELECT '=== 1月個人利益 ===' as section;
SELECT 
  user_id,
  SUM(daily_profit) as 個人利益合計,
  COUNT(DISTINCT date) as 日数
FROM nft_daily_profit
WHERE user_id IN ('59C23C', '177BB3')
  AND date >= '2026-01-01' AND date <= '2026-01-31'
GROUP BY user_id;

-- 6. 1月の出金データ
SELECT '=== 1月出金データ ===' as section;
SELECT 
  user_id,
  total_amount,
  personal_amount,
  referral_amount,
  status,
  task_completed
FROM monthly_withdrawals
WHERE user_id IN ('59C23C', '177BB3')
  AND withdrawal_month = '2026-01-01';

-- 7. 過去の出金履歴
SELECT '=== 過去の出金履歴 ===' as section;
SELECT 
  user_id,
  withdrawal_month,
  total_amount,
  personal_amount,
  referral_amount,
  status
FROM monthly_withdrawals
WHERE user_id IN ('59C23C', '177BB3')
ORDER BY user_id, withdrawal_month;

-- 8. purchases（NFT購入履歴）
SELECT '=== NFT購入履歴 ===' as section;
SELECT 
  user_id,
  nft_quantity,
  amount_usd,
  is_auto_purchase,
  cycle_number_at_purchase,
  admin_approved_at
FROM purchases
WHERE user_id IN ('59C23C', '177BB3')
ORDER BY user_id, admin_approved_at;
