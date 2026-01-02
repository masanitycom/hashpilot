-- ========================================
-- 紹介報酬を正しいデータソースから設定
-- ========================================
-- 問題: referral_amountがtotal - personalで計算されたため
--       繰越の個人利益が紹介報酬として表示されている
-- 修正: user_referral_profit_monthlyから正しい値を取得
-- ========================================

-- STEP 1: ACBFBAの確認
SELECT '=== STEP 1: ACBFBA確認 ===' as section;
SELECT
  mw.user_id,
  mw.total_amount,
  mw.personal_amount,
  mw.referral_amount as current_referral,
  COALESCE(ref.actual_referral, 0) as actual_referral
FROM monthly_withdrawals mw
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as actual_referral
  FROM user_referral_profit_monthly
  WHERE year = 2025 AND month = 12
  GROUP BY user_id
) ref ON mw.user_id = ref.user_id
WHERE mw.user_id = 'ACBFBA'
  AND mw.withdrawal_month = '2025-12-01';

-- STEP 2: 12月の紹介報酬を正しく更新（user_referral_profit_monthlyから）
SELECT '=== STEP 2: referral_amount修正 ===' as section;

UPDATE monthly_withdrawals mw
SET
  referral_amount = COALESCE(ref.actual_referral, 0),
  updated_at = NOW()
FROM (
  SELECT user_id, SUM(profit_amount) as actual_referral
  FROM user_referral_profit_monthly
  WHERE year = 2025 AND month = 12
  GROUP BY user_id
) ref
WHERE mw.user_id = ref.user_id
  AND mw.withdrawal_month = '2025-12-01';

-- 紹介報酬がないユーザーは0に設定
UPDATE monthly_withdrawals mw
SET
  referral_amount = 0,
  updated_at = NOW()
WHERE mw.withdrawal_month = '2025-12-01'
  AND NOT EXISTS (
    SELECT 1 FROM user_referral_profit_monthly urpm
    WHERE urpm.user_id = mw.user_id
      AND urpm.year = 2025 AND urpm.month = 12
  );

-- STEP 3: 結果確認
SELECT '=== STEP 3: 修正後確認 ===' as section;
SELECT
  mw.user_id,
  mw.total_amount,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount - mw.personal_amount - mw.referral_amount as carryover
FROM monthly_withdrawals mw
WHERE mw.withdrawal_month = '2025-12-01'
ORDER BY mw.total_amount DESC
LIMIT 20;

-- STEP 4: ACBFBAの確認
SELECT '=== STEP 4: ACBFBA修正後 ===' as section;
SELECT
  user_id,
  total_amount,
  personal_amount,
  referral_amount
FROM monthly_withdrawals
WHERE user_id = 'ACBFBA'
  AND withdrawal_month = '2025-12-01';

-- STEP 5: 統計情報
SELECT '=== STEP 5: 統計 ===' as section;
SELECT
  COUNT(*) as count,
  SUM(total_amount) as total,
  SUM(personal_amount) as personal,
  SUM(referral_amount) as referral
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01';
