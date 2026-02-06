-- ========================================
-- 59C23C ダッシュボード表示データ確認
-- ========================================

-- 1. affiliate_cycle（メイン表示データ）
SELECT '=== affiliate_cycle ===' as section;
SELECT 
  user_id,
  available_usdt,
  cum_usdt,
  withdrawn_referral_usdt,
  phase,
  auto_nft_count,
  manual_nft_count,
  total_nft_count
FROM affiliate_cycle
WHERE user_id = '59C23C';

-- 2. 今月の個人利益
SELECT '=== 2026年1月 個人利益 ===' as section;
SELECT 
  SUM(daily_profit) as 今月個人利益,
  COUNT(*) as レコード数
FROM nft_daily_profit
WHERE user_id = '59C23C'
  AND date >= '2026-01-01' AND date <= '2026-01-31';

-- 3. 今月の紹介報酬
SELECT '=== 2026年1月 紹介報酬 ===' as section;
SELECT 
  SUM(profit_amount) as 今月紹介報酬,
  COUNT(*) as レコード数
FROM monthly_referral_profit
WHERE user_id = '59C23C'
  AND year_month = '2026-01';

-- 4. 出金履歴
SELECT '=== 出金履歴 ===' as section;
SELECT 
  withdrawal_month,
  personal_amount,
  referral_amount,
  total_amount,
  status
FROM monthly_withdrawals
WHERE user_id = '59C23C'
ORDER BY withdrawal_month;

-- 5. NFT一覧
SELECT '=== NFT一覧 ===' as section;
SELECT 
  id,
  nft_type,
  acquired_date,
  operation_start_date,
  buyback_date
FROM nft_master
WHERE user_id = '59C23C'
ORDER BY acquired_date;

