-- ========================================
-- ユーザー0D4493の出金データ不整合調査
-- ========================================

-- 1. monthly_withdrawalsの現在の状態
SELECT '=== 1. monthly_withdrawals ===' as section;
SELECT
  user_id,
  withdrawal_month,
  total_amount,
  personal_amount,
  referral_amount,
  status
FROM monthly_withdrawals
WHERE user_id = '0D4493';

-- 2. affiliate_cycleの状態
SELECT '=== 2. affiliate_cycle ===' as section;
SELECT
  user_id,
  available_usdt,
  cum_usdt,
  phase
FROM affiliate_cycle
WHERE user_id = '0D4493';

-- 3. 12月の日利（nft_daily_profit）
SELECT '=== 3. 12月の日利 ===' as section;
SELECT
  SUM(daily_profit) as dec_personal_profit,
  COUNT(*) as days
FROM nft_daily_profit
WHERE user_id = '0D4493'
  AND date >= '2025-12-01' AND date < '2026-01-01';

-- 4. 全期間の日利累計
SELECT '=== 4. 全期間の日利累計 ===' as section;
SELECT
  SUM(daily_profit) as total_personal_profit,
  COUNT(*) as days
FROM nft_daily_profit
WHERE user_id = '0D4493';

-- 5. 12月の紹介報酬（user_referral_profit_monthly）
SELECT '=== 5. 12月の紹介報酬 ===' as section;
SELECT
  SUM(profit_amount) as dec_referral_profit
FROM user_referral_profit_monthly
WHERE user_id = '0D4493'
  AND year = 2025 AND month = 12;

-- 6. 全期間の紹介報酬累計
SELECT '=== 6. 全期間の紹介報酬累計 ===' as section;
SELECT
  SUM(profit_amount) as total_referral_profit
FROM user_referral_profit_monthly
WHERE user_id = '0D4493';

-- 7. ダッシュボードが見ているデータ（前月確定利益）
-- last-month-profit-card.tsx: 先月のuser_daily_profit + user_referral_profit_monthly
SELECT '=== 7. 11月の利益（先月） ===' as section;
SELECT
  'personal' as type,
  SUM(daily_profit) as amount
FROM nft_daily_profit
WHERE user_id = '0D4493'
  AND date >= '2025-11-01' AND date < '2025-12-01'
UNION ALL
SELECT
  'referral' as type,
  SUM(profit_amount) as amount
FROM user_referral_profit_monthly
WHERE user_id = '0D4493'
  AND year = 2025 AND month = 11;

-- 8. ダッシュボードが見ているデータ（12月確定利益）
SELECT '=== 8. 12月の利益 ===' as section;
SELECT
  'personal' as type,
  SUM(daily_profit) as amount
FROM nft_daily_profit
WHERE user_id = '0D4493'
  AND date >= '2025-12-01' AND date < '2026-01-01'
UNION ALL
SELECT
  'referral' as type,
  SUM(profit_amount) as amount
FROM user_referral_profit_monthly
WHERE user_id = '0D4493'
  AND year = 2025 AND month = 12;
