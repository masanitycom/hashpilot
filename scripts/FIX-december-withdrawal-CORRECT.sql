-- ========================================
-- 12月分出金のpersonal_amountとreferral_amountを12月分で正しく設定
-- ========================================
-- total_amount = available_usdt（累積出金可能額）
-- personal_amount = 12月の個人利益
-- referral_amount = 12月の紹介報酬
-- ※ personal + referral != total は正常（11月以前の繰越があるため）
-- ========================================

-- ========================================
-- STEP 1: personal_amountを12月の日利で更新
-- ========================================
SELECT '=== STEP 1: personal_amount（12月分）更新 ===' as section;

UPDATE monthly_withdrawals mw
SET
  personal_amount = COALESCE(daily.dec_personal, 0),
  updated_at = NOW()
FROM (
  SELECT
    user_id,
    SUM(daily_profit) as dec_personal
  FROM nft_daily_profit
  WHERE date >= '2025-12-01' AND date < '2026-01-01'
  GROUP BY user_id
) daily
WHERE mw.user_id = daily.user_id
  AND mw.withdrawal_month = '2025-12-01';

-- ========================================
-- STEP 2: referral_amountを12月の紹介報酬で更新
-- ========================================
SELECT '=== STEP 2: referral_amount（12月分）更新 ===' as section;

UPDATE monthly_withdrawals mw
SET
  referral_amount = COALESCE(referral.dec_referral, 0),
  updated_at = NOW()
FROM (
  SELECT
    user_id,
    SUM(profit_amount) as dec_referral
  FROM user_referral_profit_monthly
  WHERE year = 2025 AND month = 12
  GROUP BY user_id
) referral
WHERE mw.user_id = referral.user_id
  AND mw.withdrawal_month = '2025-12-01';

-- 紹介報酬がないユーザーは0に設定
UPDATE monthly_withdrawals
SET referral_amount = 0
WHERE withdrawal_month = '2025-12-01'
  AND referral_amount IS NULL;

-- ========================================
-- STEP 3: 0D4493の確認
-- ========================================
SELECT '=== STEP 3: 0D4493確認 ===' as section;
SELECT
  user_id,
  total_amount,
  personal_amount,
  referral_amount,
  personal_amount + referral_amount as dec_total,
  status
FROM monthly_withdrawals
WHERE user_id = '0D4493'
  AND withdrawal_month = '2025-12-01';

-- ========================================
-- STEP 4: 結果確認（上位20件）
-- ========================================
SELECT '=== STEP 4: 結果確認 ===' as section;
SELECT
  user_id,
  total_amount,
  personal_amount,
  referral_amount,
  personal_amount + referral_amount as dec_total,
  total_amount - (personal_amount + referral_amount) as carryover,
  status
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01'
ORDER BY total_amount DESC
LIMIT 20;

-- ========================================
-- STEP 5: 統計情報
-- ========================================
SELECT '=== STEP 5: 統計情報 ===' as section;
SELECT
  COUNT(*) as record_count,
  SUM(total_amount) as total_withdrawal,
  SUM(personal_amount) as dec_personal_total,
  SUM(referral_amount) as dec_referral_total,
  SUM(personal_amount + referral_amount) as dec_profit_total,
  SUM(total_amount) - SUM(personal_amount + referral_amount) as carryover_total
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01';
