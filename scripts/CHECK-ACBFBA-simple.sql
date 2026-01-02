-- ========================================
-- ACBFBA 簡易確認
-- ========================================

-- 1. ユーザー基本情報
SELECT '=== 1. ユーザー情報 ===' as section;
SELECT
  user_id,
  operation_start_date,
  has_approved_nft,
  created_at
FROM users
WHERE user_id = 'ACBFBA';

-- 2. NFT購入履歴
SELECT '=== 2. 購入履歴 ===' as section;
SELECT
  amount_usd,
  admin_approved,
  admin_approved_at,
  created_at
FROM purchases
WHERE user_id = 'ACBFBA';

-- 3. 日利履歴（月別集計）
SELECT '=== 3. 月別日利 ===' as section;
SELECT
  TO_CHAR(date, 'YYYY-MM') as month,
  SUM(daily_profit) as total_profit,
  COUNT(*) as days
FROM nft_daily_profit
WHERE user_id = 'ACBFBA'
GROUP BY TO_CHAR(date, 'YYYY-MM')
ORDER BY month;

-- 4. affiliate_cycle
SELECT '=== 4. affiliate_cycle ===' as section;
SELECT
  available_usdt,
  cum_usdt,
  phase
FROM affiliate_cycle
WHERE user_id = 'ACBFBA';

-- 5. 11月・12月の出金レコード
SELECT '=== 5. 出金レコード ===' as section;
SELECT
  withdrawal_month,
  total_amount,
  personal_amount,
  referral_amount,
  status
FROM monthly_withdrawals
WHERE user_id = 'ACBFBA'
ORDER BY withdrawal_month;
