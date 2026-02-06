-- ========================================
-- 1月のreferral_amountをmonthly_referral_profitから設定
-- ========================================

-- 1. 修正前の確認
SELECT '=== 1. 修正前：referral=0で紹介報酬がある人 ===' as section;
SELECT
  mw.user_id,
  ROUND(mrp.jan_referral::numeric, 2) as "1月紹介報酬",
  ROUND(COALESCE(mw.referral_amount, 0)::numeric, 2) as "現在referral",
  ROUND(mw.personal_amount::numeric, 2) as "personal",
  ROUND(mw.total_amount::numeric, 2) as "現在total"
FROM monthly_withdrawals mw
JOIN (
  SELECT user_id, SUM(profit_amount) as jan_referral
  FROM monthly_referral_profit
  WHERE year_month = '2026-01'
  GROUP BY user_id
) mrp ON mw.user_id = mrp.user_id
WHERE mw.withdrawal_month = '2026-01-01'
  AND mw.status IN ('pending', 'on_hold')
  AND COALESCE(mw.referral_amount, 0) = 0
ORDER BY mrp.jan_referral DESC;

-- 2. 更新実行
UPDATE monthly_withdrawals mw
SET
  referral_amount = ROUND(mrp.jan_referral::numeric, 2),
  total_amount = ROUND((mw.personal_amount + mrp.jan_referral)::numeric, 2)
FROM (
  SELECT user_id, SUM(profit_amount) as jan_referral
  FROM monthly_referral_profit
  WHERE year_month = '2026-01'
  GROUP BY user_id
) mrp
WHERE mw.user_id = mrp.user_id
  AND mw.withdrawal_month = '2026-01-01'
  AND mw.status IN ('pending', 'on_hold')
  AND COALESCE(mw.referral_amount, 0) = 0;

-- 3. 修正後の確認
SELECT '=== 3. 修正後：4名の確認 ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  ROUND(mw.personal_amount::numeric, 2) as "個人利益",
  ROUND(mw.referral_amount::numeric, 2) as "紹介報酬",
  ROUND(mw.total_amount::numeric, 2) as "出金合計"
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2026-01-01'
  AND mw.user_id IN ('59C23C', '177B83', '5FAE2C', '380CE2')
ORDER BY mw.total_amount DESC;

-- 4. 全体統計
SELECT '=== 4. 修正後の統計 ===' as section;
SELECT
  COUNT(*) as "1月pending/on_hold総数",
  COUNT(*) FILTER (WHERE COALESCE(referral_amount, 0) = 0) as "referral=0",
  COUNT(*) FILTER (WHERE COALESCE(referral_amount, 0) > 0) as "referral>0",
  ROUND(SUM(COALESCE(referral_amount, 0))::numeric, 2) as "紹介報酬合計"
FROM monthly_withdrawals
WHERE withdrawal_month = '2026-01-01'
  AND status IN ('pending', 'on_hold');
