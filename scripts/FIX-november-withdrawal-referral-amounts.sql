-- ========================================
-- 11月分出金履歴の紹介報酬を正しく設定
-- ========================================
-- 11月分は手動で紹介報酬を計算して送金済み
-- monthly_referral_profitから実際の紹介報酬を取得して設定

-- ========================================
-- STEP 1: 11月の紹介報酬を確認
-- ========================================
SELECT '【確認】11月の紹介報酬（monthly_referral_profit）' as section;
SELECT
  user_id,
  SUM(profit_amount) as total_referral
FROM monthly_referral_profit
WHERE year_month = '2025-11'
GROUP BY user_id
ORDER BY total_referral DESC
LIMIT 20;

-- ========================================
-- STEP 2: 現在の出金履歴と紹介報酬を比較
-- ========================================
SELECT '【確認】出金履歴 vs 紹介報酬' as section;
SELECT
  mw.user_id,
  mw.total_amount,
  mw.personal_amount,
  mw.referral_amount as current_referral,
  COALESCE(mrp.total_referral, 0) as actual_referral
FROM monthly_withdrawals mw
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  WHERE year_month = '2025-11'
  GROUP BY user_id
) mrp ON mw.user_id = mrp.user_id
WHERE mw.withdrawal_month = '2025-11-01'
ORDER BY mw.total_amount DESC
LIMIT 20;

-- ========================================
-- STEP 3: 11月分の紹介報酬を正しく更新
-- ========================================
SELECT '【実行】11月分出金履歴の紹介報酬を更新' as section;

UPDATE monthly_withdrawals mw
SET
  referral_amount = COALESCE(mrp.total_referral, 0)
FROM (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  WHERE year_month = '2025-11'
  GROUP BY user_id
) mrp
WHERE mw.user_id = mrp.user_id
  AND mw.withdrawal_month = '2025-11-01';

-- referral_amountがNULLのままの場合は0に設定
UPDATE monthly_withdrawals
SET referral_amount = 0
WHERE withdrawal_month = '2025-11-01'
  AND referral_amount IS NULL;

-- ========================================
-- STEP 4: 更新結果を確認
-- ========================================
SELECT '【確認】更新後の11月分出金履歴' as section;
SELECT
  user_id,
  total_amount,
  personal_amount,
  referral_amount,
  status
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01'
ORDER BY total_amount DESC
LIMIT 20;

-- 紹介報酬がある人の合計
SELECT '【サマリー】11月紹介報酬' as section;
SELECT
  COUNT(*) as users_with_referral,
  SUM(referral_amount) as total_referral_amount
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01'
  AND referral_amount > 0;
