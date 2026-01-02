-- ========================================
-- 12月分出金履歴のpersonal_amountとreferral_amountを正しく設定
-- ========================================
-- 実行日: 2026-01-01
--
-- 問題: process_monthly_withdrawals関数がpersonal_amountとreferral_amountを
--       設定せずにtotal_amountのみを保存している
-- 修正: 日利データと紹介報酬データから正しい値を計算して更新
-- ========================================

-- ========================================
-- STEP 1: 現状確認
-- ========================================
SELECT '=== STEP 1: 修正前の状態 ===' as section;
SELECT
  user_id,
  total_amount,
  personal_amount,
  referral_amount,
  status
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01'
ORDER BY total_amount DESC
LIMIT 10;

-- ========================================
-- STEP 2: personal_amountを更新
-- nft_daily_profitから12月の日利合計を取得
-- ========================================
SELECT '=== STEP 2: personal_amount更新 ===' as section;

-- ⭐ 重要: user_daily_profitビューではなくnft_daily_profitテーブルを使用
UPDATE monthly_withdrawals mw
SET
  personal_amount = COALESCE(daily.total_daily_profit, 0),
  updated_at = NOW()
FROM (
  SELECT
    user_id,
    SUM(daily_profit) as total_daily_profit
  FROM nft_daily_profit
  WHERE date >= '2025-12-01' AND date < '2026-01-01'
  GROUP BY user_id
) daily
WHERE mw.user_id = daily.user_id
  AND mw.withdrawal_month = '2025-12-01';

-- ========================================
-- STEP 3: referral_amountを更新
-- user_referral_profit_monthlyから12月の紹介報酬合計を取得
-- ========================================
SELECT '=== STEP 3: referral_amount更新 ===' as section;

UPDATE monthly_withdrawals mw
SET
  referral_amount = COALESCE(referral.total_referral_profit, 0),
  updated_at = NOW()
FROM (
  SELECT
    user_id,
    SUM(profit_amount) as total_referral_profit
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
-- STEP 4: 結果確認
-- ========================================
SELECT '=== STEP 4: 修正後の確認 ===' as section;

SELECT
  user_id,
  total_amount,
  personal_amount,
  referral_amount,
  personal_amount + referral_amount as calculated_total,
  ABS(total_amount - (personal_amount + COALESCE(referral_amount, 0))) as difference,
  status
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01'
ORDER BY total_amount DESC
LIMIT 20;

-- 統計情報
SELECT '=== 統計情報 ===' as section;
SELECT
  COUNT(*) as record_count,
  SUM(total_amount) as total_withdrawal,
  SUM(personal_amount) as total_personal,
  SUM(referral_amount) as total_referral
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01';
