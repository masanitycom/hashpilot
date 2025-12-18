-- ========================================
-- 全ユーザーのavailable_usdtが正しいか確認
-- 11月出金完了後、available_usdtは12月の日利のみであるべき
-- ========================================

-- 1. 11月出金完了ユーザーのavailable_usdt状況
SELECT '【1】11月出金完了ユーザーのavailable_usdt確認' as section;
SELECT
  ac.user_id,
  ac.available_usdt as 現在のavailable_usdt,
  ac.phase,
  mw.total_amount as 出金済み額,
  mw.personal_amount as 出金済み個人利益,
  mw.referral_amount as 出金済み紹介報酬,
  COALESCE(dec.december_profit, 0) as dec_profit,
  ac.available_usdt - COALESCE(dec.december_profit, 0) as diff
FROM affiliate_cycle ac
INNER JOIN monthly_withdrawals mw ON ac.user_id = mw.user_id
  AND mw.withdrawal_month = '2025-11-01'
  AND mw.status = 'completed'
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as december_profit
  FROM nft_daily_profit
  WHERE date >= '2025-12-01'
  GROUP BY user_id
) dec ON ac.user_id = dec.user_id
WHERE ac.available_usdt > COALESCE(dec.december_profit, 0) + 0.01  -- 誤差許容
ORDER BY ac.available_usdt - COALESCE(dec.december_profit, 0) DESC;

-- 2. 問題のあるユーザー数
SELECT '【2】available_usdtがリセットされていないユーザー数' as section;
SELECT
  COUNT(*) as 問題ユーザー数,
  SUM(ac.available_usdt - COALESCE(dec.december_profit, 0)) as 差額合計
FROM affiliate_cycle ac
INNER JOIN monthly_withdrawals mw ON ac.user_id = mw.user_id
  AND mw.withdrawal_month = '2025-11-01'
  AND mw.status = 'completed'
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as december_profit
  FROM nft_daily_profit
  WHERE date >= '2025-12-01'
  GROUP BY user_id
) dec ON ac.user_id = dec.user_id
WHERE ac.available_usdt > COALESCE(dec.december_profit, 0) + 0.01;
