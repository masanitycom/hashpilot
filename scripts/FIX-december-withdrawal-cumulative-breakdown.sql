-- ========================================
-- 12月分出金のpersonal_amountとreferral_amountを累積で設定
-- ========================================
-- 重要: total_amount = 累積出金額（正しい）
--       personal_amount = 累積個人利益
--       referral_amount = 累積紹介報酬（出金可能分）
-- ========================================

-- ========================================
-- STEP 1: 修正前の状態確認
-- ========================================
SELECT '=== STEP 1: 修正前の状態 ===' as section;
SELECT
  user_id,
  total_amount,
  personal_amount,
  referral_amount,
  total_amount - (personal_amount + COALESCE(referral_amount, 0)) as difference
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01'
ORDER BY total_amount DESC
LIMIT 10;

-- ========================================
-- STEP 2: personal_amountを累積個人利益で更新
-- nft_daily_profitの全期間合計
-- ========================================
SELECT '=== STEP 2: personal_amount累積更新 ===' as section;

UPDATE monthly_withdrawals mw
SET
  personal_amount = COALESCE(daily.total_personal, 0),
  updated_at = NOW()
FROM (
  SELECT
    user_id,
    SUM(daily_profit) as total_personal
  FROM nft_daily_profit
  GROUP BY user_id
) daily
WHERE mw.user_id = daily.user_id
  AND mw.withdrawal_month = '2025-12-01';

-- ========================================
-- STEP 3: referral_amountを累積紹介報酬で更新
-- user_referral_profit_monthlyの全期間合計
-- ただしHOLDフェーズのユーザーは出金不可なので考慮が必要
-- ========================================
SELECT '=== STEP 3: referral_amount累積更新 ===' as section;

-- 紹介報酬の累積 = total_amount - personal_amount
-- これでtotal_amount = personal_amount + referral_amountになる
UPDATE monthly_withdrawals mw
SET
  referral_amount = mw.total_amount - mw.personal_amount,
  updated_at = NOW()
WHERE mw.withdrawal_month = '2025-12-01';

-- マイナスになった場合は0に修正
UPDATE monthly_withdrawals
SET referral_amount = 0
WHERE withdrawal_month = '2025-12-01'
  AND referral_amount < 0;

-- referral_amountがマイナスだった場合はpersonal_amountを調整
UPDATE monthly_withdrawals
SET personal_amount = total_amount
WHERE withdrawal_month = '2025-12-01'
  AND referral_amount = 0
  AND personal_amount != total_amount;

-- ========================================
-- STEP 4: 結果確認
-- ========================================
SELECT '=== STEP 4: 修正後の確認 ===' as section;

SELECT
  user_id,
  total_amount,
  personal_amount,
  referral_amount,
  personal_amount + referral_amount as calculated_total,
  total_amount - (personal_amount + referral_amount) as difference,
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
  SUM(personal_amount) as total_personal,
  SUM(referral_amount) as total_referral,
  SUM(total_amount) - (SUM(personal_amount) + SUM(referral_amount)) as total_difference
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01';

-- ========================================
-- STEP 6: 差異がないか最終確認
-- ========================================
SELECT '=== STEP 6: 差異チェック ===' as section;
SELECT COUNT(*) as mismatch_count
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01'
  AND ABS(total_amount - (personal_amount + referral_amount)) > 0.01;
