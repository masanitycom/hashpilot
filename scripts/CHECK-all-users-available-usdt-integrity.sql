-- ========================================
-- 全ユーザーのavailable_usdt整合性チェック
-- ========================================

SELECT '=== available_usdt不整合ユーザー ===' as section;
WITH profit_sum AS (
  SELECT user_id, SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  GROUP BY user_id
),
withdrawal_sum AS (
  SELECT user_id, SUM(total_amount) as total_withdrawn
  FROM monthly_withdrawals
  WHERE status = 'completed'
  GROUP BY user_id
),
correct_values AS (
  SELECT 
    ac.user_id,
    ac.available_usdt as 現在値,
    ROUND((COALESCE(ps.total_profit, 0) + ac.withdrawn_referral_usdt + (ac.auto_nft_count * 1100) - COALESCE(ws.total_withdrawn, 0))::numeric, 2) as 計算値,
    ROUND((ac.available_usdt - (COALESCE(ps.total_profit, 0) + ac.withdrawn_referral_usdt + (ac.auto_nft_count * 1100) - COALESCE(ws.total_withdrawn, 0)))::numeric, 2) as 差額
  FROM affiliate_cycle ac
  LEFT JOIN profit_sum ps ON ac.user_id = ps.user_id
  LEFT JOIN withdrawal_sum ws ON ac.user_id = ws.user_id
)
SELECT *
FROM correct_values
WHERE ABS(差額) > 0.1
ORDER BY ABS(差額) DESC;

-- 不整合件数
SELECT '=== 不整合件数 ===' as section;
WITH profit_sum AS (
  SELECT user_id, SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  GROUP BY user_id
),
withdrawal_sum AS (
  SELECT user_id, SUM(total_amount) as total_withdrawn
  FROM monthly_withdrawals
  WHERE status = 'completed'
  GROUP BY user_id
)
SELECT 
  COUNT(*) as 不整合件数,
  SUM(ABS(ac.available_usdt - (COALESCE(ps.total_profit, 0) + ac.withdrawn_referral_usdt + (ac.auto_nft_count * 1100) - COALESCE(ws.total_withdrawn, 0)))) as 差額合計
FROM affiliate_cycle ac
LEFT JOIN profit_sum ps ON ac.user_id = ps.user_id
LEFT JOIN withdrawal_sum ws ON ac.user_id = ws.user_id
WHERE ABS(ac.available_usdt - (COALESCE(ps.total_profit, 0) + ac.withdrawn_referral_usdt + (ac.auto_nft_count * 1100) - COALESCE(ws.total_withdrawn, 0))) > 0.1;
