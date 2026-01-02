-- ========================================
-- ACBFBA の available_usdt を正しい値に修正
-- ========================================
-- 問題: available_usdt = $4,023.02
-- 正しい値: 12月日利 $1,989.68 + 紹介報酬 $0 = $1,989.68
-- 差額: $2,033.34 が不明な加算
-- ========================================

-- STEP 1: 修正前確認
SELECT '=== 修正前 ===' as section;
SELECT
  user_id,
  available_usdt,
  cum_usdt,
  phase
FROM affiliate_cycle
WHERE user_id = 'ACBFBA';

-- STEP 2: available_usdtを正しい値に修正
UPDATE affiliate_cycle
SET
  available_usdt = 1989.68,
  updated_at = NOW()
WHERE user_id = 'ACBFBA';

-- STEP 3: 修正後確認
SELECT '=== 修正後 ===' as section;
SELECT
  user_id,
  available_usdt,
  cum_usdt,
  phase
FROM affiliate_cycle
WHERE user_id = 'ACBFBA';

-- STEP 4: 12月出金レコードも修正
UPDATE monthly_withdrawals
SET
  total_amount = 1989.68,
  personal_amount = 1989.68,
  referral_amount = 0,
  updated_at = NOW()
WHERE user_id = 'ACBFBA'
  AND withdrawal_month = '2025-12-01';

-- STEP 5: 出金レコード確認
SELECT '=== 出金レコード修正後 ===' as section;
SELECT
  user_id,
  total_amount,
  personal_amount,
  referral_amount,
  status
FROM monthly_withdrawals
WHERE user_id = 'ACBFBA'
  AND withdrawal_month = '2025-12-01';
