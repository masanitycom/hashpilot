-- ========================================
-- 12月分出金のreferral_amountを正しく更新
-- ========================================
-- 問題: FIX-december-withdrawal-CORRECT.sql で
--       user_referral_profit_monthly テーブルを参照していたが、
--       正しいテーブルは monthly_referral_profit
-- ========================================
--
-- 紹介報酬の出金ルール:
-- - 12月末出金 = 11月分の紹介報酬 (monthly_referral_profit WHERE year_month = '2025-11')
-- - ただし、USDTフェーズのユーザーのみ（HOLDフェーズは出金不可）
-- ========================================

-- ========================================
-- STEP 1: 現状確認（referral_amount = 0 のユーザー）
-- ========================================
SELECT '=== STEP 1: referral_amount = 0 のユーザー確認 ===' as section;

SELECT
  mw.user_id,
  mw.total_amount,
  mw.personal_amount,
  mw.referral_amount as current_referral,
  COALESCE(mrp.nov_referral, 0) as nov_referral,
  ac.phase,
  ac.cum_usdt
FROM monthly_withdrawals mw
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as nov_referral
  FROM monthly_referral_profit
  WHERE year_month = '2025-11'
  GROUP BY user_id
) mrp ON mw.user_id = mrp.user_id
LEFT JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND (mw.referral_amount = 0 OR mw.referral_amount IS NULL)
  AND mrp.nov_referral > 0
ORDER BY mrp.nov_referral DESC
LIMIT 30;

-- ========================================
-- STEP 2: A81A5Eの詳細確認
-- ========================================
SELECT '=== STEP 2: A81A5E詳細 ===' as section;

SELECT
  mw.user_id,
  mw.total_amount,
  mw.personal_amount,
  mw.referral_amount,
  mw.status,
  ac.phase,
  ac.cum_usdt,
  ac.available_usdt
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.user_id = 'A81A5E'
  AND mw.withdrawal_month = '2025-12-01';

SELECT '--- A81A5Eの11月紹介報酬 ---' as section;
SELECT *
FROM monthly_referral_profit
WHERE user_id = 'A81A5E'
  AND year_month = '2025-11';

-- ========================================
-- STEP 3: 影響を受けるユーザー数の確認
-- ========================================
SELECT '=== STEP 3: 影響を受けるユーザー数 ===' as section;

SELECT
  COUNT(*) as affected_users,
  SUM(mrp.nov_referral) as total_missing_referral
FROM (
  SELECT user_id, SUM(profit_amount) as nov_referral
  FROM monthly_referral_profit
  WHERE year_month = '2025-11'
  GROUP BY user_id
) mrp
JOIN monthly_withdrawals mw ON mrp.user_id = mw.user_id AND mw.withdrawal_month = '2025-12-01'
WHERE (mw.referral_amount = 0 OR mw.referral_amount IS NULL);

-- ========================================
-- STEP 4: referral_amountを正しく更新
-- monthly_referral_profit の 11月分を使用
-- ========================================
SELECT '=== STEP 4: referral_amount更新（11月分紹介報酬） ===' as section;

-- 注意: 12月分ではなく11月分の紹介報酬を使用
-- 理由: 紹介報酬は月末に確定し、翌月に出金可能になるため
UPDATE monthly_withdrawals mw
SET
  referral_amount = COALESCE(mrp.nov_referral, 0),
  updated_at = NOW()
FROM (
  SELECT user_id, SUM(profit_amount) as nov_referral
  FROM monthly_referral_profit
  WHERE year_month = '2025-11'
  GROUP BY user_id
) mrp
WHERE mw.user_id = mrp.user_id
  AND mw.withdrawal_month = '2025-12-01';

-- referral_amountがNULLのままの場合は0に設定
UPDATE monthly_withdrawals
SET referral_amount = 0
WHERE withdrawal_month = '2025-12-01'
  AND referral_amount IS NULL;

-- ========================================
-- STEP 5: 更新後の確認
-- ========================================
SELECT '=== STEP 5: 更新後の確認 ===' as section;

SELECT
  mw.user_id,
  mw.total_amount,
  mw.personal_amount,
  mw.referral_amount,
  mw.personal_amount + mw.referral_amount as dec_total,
  mw.total_amount - (mw.personal_amount + mw.referral_amount) as carryover,
  ac.phase,
  mw.status
FROM monthly_withdrawals mw
LEFT JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
ORDER BY mw.referral_amount DESC
LIMIT 30;

-- ========================================
-- STEP 6: A81A5E更新後確認
-- ========================================
SELECT '=== STEP 6: A81A5E更新後確認 ===' as section;

SELECT
  mw.user_id,
  mw.total_amount,
  mw.personal_amount,
  mw.referral_amount,
  mw.status
FROM monthly_withdrawals mw
WHERE mw.user_id = 'A81A5E'
  AND mw.withdrawal_month = '2025-12-01';

-- ========================================
-- STEP 7: 統計情報
-- ========================================
SELECT '=== STEP 7: 統計情報 ===' as section;

SELECT
  COUNT(*) as record_count,
  SUM(total_amount) as total_withdrawal,
  SUM(personal_amount) as personal_total,
  SUM(referral_amount) as referral_total,
  SUM(personal_amount + referral_amount) as dec_profit_total
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01';
