-- ========================================
-- 177B83 フェーズ修正と12月出金レコード修正
-- ========================================

-- 問題:
-- 1. phaseがUSDTになっているが、計算上はHOLD
-- 2. 12月出金レコードのreferral_amountが$813.44だが、
--    実際に払い出し可能なのは$33.71（$1,100 - $1,066.29 = 既払い分）

-- ========================================
-- 修正前の確認
-- ========================================
SELECT '=== 修正前: 177B83の状態 ===' as section;
SELECT
  user_id,
  cum_usdt,
  available_usdt,
  phase,
  withdrawn_referral_usdt
FROM affiliate_cycle
WHERE user_id = '177B83';

SELECT '=== 修正前: 12月出金レコード ===' as section;
SELECT
  id,
  user_id,
  withdrawal_month,
  total_amount,
  personal_amount,
  referral_amount,
  status
FROM monthly_withdrawals
WHERE user_id = '177B83' AND withdrawal_month = '2025-12-01';

-- ========================================
-- STEP 1: フェーズをHOLDに修正
-- ========================================
UPDATE affiliate_cycle
SET phase = 'HOLD'
WHERE user_id = '177B83';

-- ========================================
-- STEP 2: 12月出金レコードの紹介報酬額を修正
-- 払い出し可能額 = $1,100 - $1,066.29 = $33.71
-- ========================================
UPDATE monthly_withdrawals
SET
  referral_amount = 33.71,
  total_amount = personal_amount + 33.71
WHERE user_id = '177B83'
  AND withdrawal_month = '2025-12-01';

-- ========================================
-- 修正後の確認
-- ========================================
SELECT '=== 修正後: 177B83の状態 ===' as section;
SELECT
  user_id,
  cum_usdt,
  available_usdt,
  phase,
  withdrawn_referral_usdt,
  '払い出し可能額' as label,
  GREATEST(1100 - COALESCE(withdrawn_referral_usdt, 0), 0) as withdrawable_from_hold
FROM affiliate_cycle
WHERE user_id = '177B83';

SELECT '=== 修正後: 12月出金レコード ===' as section;
SELECT
  id,
  user_id,
  withdrawal_month,
  total_amount,
  personal_amount,
  referral_amount,
  status
FROM monthly_withdrawals
WHERE user_id = '177B83' AND withdrawal_month = '2025-12-01';

-- ========================================
-- 計算確認
-- ========================================
SELECT '=== 計算確認 ===' as section;
SELECT
  '個人利益（日利）' as item,
  23.408 as amount,
  '払い出し可能' as status
UNION ALL
SELECT
  '紹介報酬（ロック$1,100から）' as item,
  33.71 as amount,
  '$1,100 - $1,066.29（11月払い出し済み）= $33.71' as status
UNION ALL
SELECT
  '合計' as item,
  23.408 + 33.71 as amount,
  '約$57.12' as status;
