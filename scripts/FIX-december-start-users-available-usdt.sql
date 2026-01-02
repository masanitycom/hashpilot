-- ========================================
-- 12月開始ユーザーのavailable_usdtを修正
-- ========================================
-- 問題: available_usdtが過大になっている
-- 原因: 不明な加算が発生
-- 修正: 日利合計 + 紹介報酬合計 = 正しいavailable_usdt
-- ========================================

-- STEP 1: 対象ユーザー確認
SELECT '=== STEP 1: 修正対象ユーザー ===' as section;
SELECT
  ac.user_id,
  u.operation_start_date,
  ac.available_usdt as current,
  COALESCE(dp.total_profit, 0) + COALESCE(rp.total_referral, 0) as correct,
  ac.available_usdt - (COALESCE(dp.total_profit, 0) + COALESCE(rp.total_referral, 0)) as over_amount
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  GROUP BY user_id
) dp ON ac.user_id = dp.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM user_referral_profit_monthly
  GROUP BY user_id
) rp ON ac.user_id = rp.user_id
WHERE u.operation_start_date >= '2025-12-01'
  AND ac.available_usdt - (COALESCE(dp.total_profit, 0) + COALESCE(rp.total_referral, 0)) > 1
ORDER BY ac.available_usdt - (COALESCE(dp.total_profit, 0) + COALESCE(rp.total_referral, 0)) DESC;

-- STEP 2: affiliate_cycleを修正
SELECT '=== STEP 2: available_usdt修正 ===' as section;

UPDATE affiliate_cycle ac
SET
  available_usdt = COALESCE(dp.total_profit, 0) + COALESCE(rp.total_referral, 0),
  updated_at = NOW()
FROM users u
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  GROUP BY user_id
) dp ON u.user_id = dp.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM user_referral_profit_monthly
  GROUP BY user_id
) rp ON u.user_id = rp.user_id
WHERE ac.user_id = u.user_id
  AND u.operation_start_date >= '2025-12-01'
  AND ac.available_usdt - (COALESCE(dp.total_profit, 0) + COALESCE(rp.total_referral, 0)) > 1;

-- STEP 3: 修正後確認
SELECT '=== STEP 3: 修正後確認 ===' as section;
SELECT
  ac.user_id,
  u.operation_start_date,
  ac.available_usdt,
  COALESCE(dp.total_profit, 0) as daily_profit,
  COALESCE(rp.total_referral, 0) as referral
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  GROUP BY user_id
) dp ON ac.user_id = dp.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM user_referral_profit_monthly
  GROUP BY user_id
) rp ON ac.user_id = rp.user_id
WHERE u.operation_start_date >= '2025-12-01'
ORDER BY ac.available_usdt DESC
LIMIT 20;

-- STEP 4: 12月出金レコードも修正
SELECT '=== STEP 4: 出金レコード修正 ===' as section;

UPDATE monthly_withdrawals mw
SET
  total_amount = ac.available_usdt,
  updated_at = NOW()
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE mw.user_id = ac.user_id
  AND mw.withdrawal_month = '2025-12-01'
  AND u.operation_start_date >= '2025-12-01';

-- STEP 5: 出金レコード確認
SELECT '=== STEP 5: 出金レコード確認 ===' as section;
SELECT
  mw.user_id,
  mw.total_amount,
  mw.personal_amount,
  mw.referral_amount,
  mw.status
FROM monthly_withdrawals mw
JOIN users u ON mw.user_id = u.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND u.operation_start_date >= '2025-12-01'
ORDER BY mw.total_amount DESC
LIMIT 20;

-- STEP 6: 統計
SELECT '=== STEP 6: 12月統計 ===' as section;
SELECT
  COUNT(*) as count,
  SUM(total_amount) as total,
  SUM(personal_amount) as personal,
  SUM(referral_amount) as referral
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01';
