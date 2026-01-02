-- ========================================
-- ACBFBA 全履歴調査
-- ========================================

-- 1. ユーザー基本情報
SELECT '=== 1. ユーザー基本情報 ===' as section;
SELECT
  user_id,
  email,
  operation_start_date,
  has_approved_nft,
  created_at
FROM users
WHERE user_id = 'ACBFBA';

-- 2. 日利履歴（全期間）
SELECT '=== 2. 日利履歴（全期間） ===' as section;
SELECT
  date,
  daily_profit
FROM nft_daily_profit
WHERE user_id = 'ACBFBA'
ORDER BY date;

-- 3. 月別日利集計
SELECT '=== 3. 月別日利集計 ===' as section;
SELECT
  EXTRACT(YEAR FROM date) as year,
  EXTRACT(MONTH FROM date) as month,
  SUM(daily_profit) as total,
  COUNT(*) as days
FROM nft_daily_profit
WHERE user_id = 'ACBFBA'
GROUP BY EXTRACT(YEAR FROM date), EXTRACT(MONTH FROM date)
ORDER BY year, month;

-- 4. affiliate_cycle履歴
SELECT '=== 4. affiliate_cycle ===' as section;
SELECT
  user_id,
  available_usdt,
  cum_usdt,
  phase,
  auto_nft_count,
  manual_nft_count,
  updated_at
FROM affiliate_cycle
WHERE user_id = 'ACBFBA';

-- 5. 出金履歴
SELECT '=== 5. 出金履歴 ===' as section;
SELECT
  withdrawal_month,
  total_amount,
  personal_amount,
  referral_amount,
  status,
  created_at
FROM monthly_withdrawals
WHERE user_id = 'ACBFBA'
ORDER BY withdrawal_month;

-- 6. 日利の総合計
SELECT '=== 6. 日利総合計 ===' as section;
SELECT
  SUM(daily_profit) as total_daily_profit
FROM nft_daily_profit
WHERE user_id = 'ACBFBA';
