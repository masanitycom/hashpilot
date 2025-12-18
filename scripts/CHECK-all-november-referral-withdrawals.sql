-- ========================================
-- 11月に紹介報酬を出金した全ユーザーの
-- withdrawn_referral_usdtが正しいか確認
-- ========================================

SELECT
  mw.user_id,
  mw.referral_amount as withdrawn_in_november,
  ac.cum_usdt,
  ac.withdrawn_referral_usdt,
  ac.phase,
  CASE
    WHEN mw.referral_amount > 0 AND ac.withdrawn_referral_usdt = 0 THEN '❌ 要修正'
    WHEN mw.referral_amount > 0 AND ac.withdrawn_referral_usdt < mw.referral_amount THEN '⚠️ 差額あり'
    ELSE '✅ OK'
  END as status
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-11-01'
  AND mw.status = 'completed'
  AND mw.referral_amount > 0
ORDER BY mw.referral_amount DESC;
