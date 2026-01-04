-- ========================================
-- 12月未払い紹介報酬リスト（CSV出力用）
-- ========================================
-- Supabaseで実行し、結果をCSVでダウンロード
-- ========================================

SELECT
  mw.user_id as "ユーザーID",
  u.email as "メールアドレス",
  u.coinw_uid as "CoinW_UID",
  mw.personal_amount as "個人利益",
  mw.referral_amount as "11月紹介報酬",
  mw.total_amount as "支払済み",
  (mw.personal_amount + mw.referral_amount) - mw.total_amount as "追加支払い額",
  ac.phase as "フェーズ",
  mw.status as "ステータス"
FROM monthly_withdrawals mw
JOIN users u ON mw.user_id = u.user_id
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND mw.referral_amount > 0
  AND mw.total_amount < (mw.personal_amount + mw.referral_amount)
  AND ac.phase = 'USDT'
ORDER BY (mw.personal_amount + mw.referral_amount) - mw.total_amount DESC;
