-- ========================================
-- 11月分出金履歴のpersonal_amountを日利から正しく設定
-- ========================================

-- personal_amount = 11月の日利合計（nft_daily_profitから）
UPDATE monthly_withdrawals mw
SET
  personal_amount = COALESCE(daily.total_daily_profit, 0)
FROM (
  SELECT
    user_id,
    SUM(daily_profit) as total_daily_profit
  FROM nft_daily_profit
  WHERE date >= '2025-11-01' AND date < '2025-12-01'
  GROUP BY user_id
) daily
WHERE mw.user_id = daily.user_id
  AND mw.withdrawal_month = '2025-11-01';

-- 確認
SELECT
  user_id,
  total_amount,
  personal_amount,
  referral_amount,
  personal_amount + referral_amount as calculated_total,
  status
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-11-01'
  AND referral_amount > 1
ORDER BY referral_amount DESC
LIMIT 20;
