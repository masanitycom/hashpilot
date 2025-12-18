-- ========================================
-- 11月に紹介報酬を出金した全ユーザーの
-- withdrawn_referral_usdtを一括修正
-- ========================================

-- 修正前確認
SELECT '【修正前】要修正ユーザー数' as section;
SELECT COUNT(*) as count
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-11-01'
  AND mw.status = 'completed'
  AND mw.referral_amount > 0
  AND ac.withdrawn_referral_usdt = 0;

-- 一括更新
UPDATE affiliate_cycle ac
SET withdrawn_referral_usdt = mw.referral_amount
FROM monthly_withdrawals mw
WHERE ac.user_id = mw.user_id
  AND mw.withdrawal_month = '2025-11-01'
  AND mw.status = 'completed'
  AND mw.referral_amount > 0
  AND ac.withdrawn_referral_usdt = 0;

-- 修正後確認
SELECT '【修正後】要修正ユーザー数（0になるべき）' as section;
SELECT COUNT(*) as count
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-11-01'
  AND mw.status = 'completed'
  AND mw.referral_amount > 0
  AND ac.withdrawn_referral_usdt = 0;

-- サマリー
SELECT '【サマリー】修正されたユーザーの合計額' as section;
SELECT
  COUNT(*) as user_count,
  SUM(withdrawn_referral_usdt) as total_withdrawn_referral
FROM affiliate_cycle
WHERE withdrawn_referral_usdt > 0;
