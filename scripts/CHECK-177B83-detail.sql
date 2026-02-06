-- ========================================
-- 177B83の詳細確認
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
WHERE user_id = '177B83';

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
WHERE user_id = '177B83'
ORDER BY nft_sequence;

-- 3. 全期間の紹介報酬累計
SELECT '=== 紹介報酬累計 ===' as section;
SELECT 
  SUM(profit_amount) as 紹介報酬累計
FROM monthly_referral_profit
WHERE user_id = '177B83';

-- 4. 過去の出金履歴
SELECT '=== 出金履歴 ===' as section;
SELECT 
  withdrawal_month,
  total_amount,
  personal_amount,
  referral_amount,
  status
FROM monthly_withdrawals
WHERE user_id = '177B83'
ORDER BY withdrawal_month;

-- 5. 1月の個人利益
SELECT '=== 1月個人利益 ===' as section;
SELECT 
  SUM(daily_profit) as 個人利益合計,
  COUNT(DISTINCT date) as 日数
FROM nft_daily_profit
WHERE user_id = '177B83'
  AND date >= '2026-01-01' AND date <= '2026-01-31';

-- 6. 1月の日利詳細（日別NFT数）
SELECT '=== 1月日利詳細 ===' as section;
SELECT 
  date,
  COUNT(*) as nft_count,
  SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE user_id = '177B83'
  AND date >= '2026-01-01' AND date <= '2026-01-31'
GROUP BY date
ORDER BY date;
