-- ========================================
-- 全ユーザーのavailable_usdt不整合チェック
-- ========================================
-- available_usdt = 日利合計 + 紹介報酬合計 であるべき
-- 差額があるユーザーを特定
-- ========================================

SELECT '=== available_usdt不整合ユーザー ===' as section;
SELECT
  ac.user_id,
  u.operation_start_date,
  ac.available_usdt,
  COALESCE(dp.total_profit, 0) as daily_profit_total,
  COALESCE(rp.total_referral, 0) as referral_total,
  COALESCE(dp.total_profit, 0) + COALESCE(rp.total_referral, 0) as expected_available,
  ac.available_usdt - (COALESCE(dp.total_profit, 0) + COALESCE(rp.total_referral, 0)) as difference
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  GROUP BY user_id
) dp ON ac.user_id = dp.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM user_referral_profit_monthly
  GROUP BY user_id
) rp ON ac.user_id = rp.user_id
WHERE ABS(ac.available_usdt - (COALESCE(dp.total_profit, 0) + COALESCE(rp.total_referral, 0))) > 1
ORDER BY ABS(ac.available_usdt - (COALESCE(dp.total_profit, 0) + COALESCE(rp.total_referral, 0))) DESC
LIMIT 30;
