-- ========================================
-- 1月referral=0のユーザーリスト（201名）
-- ========================================

SELECT
  mw.user_id,
  mw.status,
  ac.phase,
  ROUND(mw.personal_amount::numeric, 2) as "個人利益",
  ROUND(COALESCE(mw.referral_amount, 0)::numeric, 2) as "紹介報酬",
  ROUND(mw.total_amount::numeric, 2) as "出金合計",
  (SELECT COUNT(*) FROM users child WHERE child.referrer_user_id = mw.user_id) as "紹介者数"
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2026-01-01'
  AND mw.status IN ('pending', 'on_hold')
  AND COALESCE(mw.referral_amount, 0) = 0
ORDER BY mw.personal_amount DESC;
