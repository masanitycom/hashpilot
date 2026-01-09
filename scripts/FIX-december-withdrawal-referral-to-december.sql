-- ========================================
-- 12月出金のreferral_amountを12月分の紹介報酬に修正
-- ========================================
-- 実行日: 2026-01-09
-- 問題: FIX-december-withdrawal-referral-CORRECT.sql で
--       誤って11月分の紹介報酬が設定されていた
-- 修正: 12月分の紹介報酬に更新
-- ========================================

-- ========================================
-- STEP 1: 修正前の確認
-- ========================================
SELECT '=== 修正前の状態 ===' as section;
SELECT
  COUNT(*) as record_count,
  SUM(referral_amount) as current_referral_total,
  SUM(personal_amount) as personal_total,
  SUM(total_amount) as total_withdrawal
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01';

-- ========================================
-- STEP 2: 12月出金のreferral_amountを12月分に更新
-- ========================================
UPDATE monthly_withdrawals mw
SET
  referral_amount = COALESCE(mrp.dec_referral, 0),
  updated_at = NOW()
FROM (
  SELECT user_id, SUM(profit_amount) as dec_referral
  FROM monthly_referral_profit
  WHERE year_month = '2025-12'
  GROUP BY user_id
) mrp
WHERE mw.user_id = mrp.user_id
  AND mw.withdrawal_month = '2025-12-01';

-- STEP 3: 12月分の紹介報酬がないユーザーは0に設定
UPDATE monthly_withdrawals
SET referral_amount = 0, updated_at = NOW()
WHERE withdrawal_month = '2025-12-01'
  AND referral_amount IS NULL;

-- ========================================
-- STEP 4: 修正後の確認
-- ========================================
SELECT '=== 修正後の状態 ===' as section;
SELECT
  COUNT(*) as record_count,
  SUM(referral_amount) as new_referral_total,
  SUM(personal_amount) as personal_total,
  SUM(total_amount) as total_withdrawal
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01';

-- ========================================
-- STEP 5: 上位ユーザーの確認
-- ========================================
SELECT '=== 上位ユーザー確認 ===' as section;
SELECT
  mw.user_id,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount,
  ac.phase
FROM monthly_withdrawals mw
LEFT JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
ORDER BY mw.referral_amount DESC
LIMIT 20;

-- ========================================
-- 完了メッセージ
-- ========================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE '12月出金のreferral_amountを12月分に修正完了';
  RAISE NOTICE '========================================';
END $$;
