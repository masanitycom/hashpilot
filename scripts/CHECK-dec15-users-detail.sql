-- ========================================
-- 12/15運用開始ユーザーの詳細
-- ========================================

SELECT '=== 12/15運用開始ユーザーの月別損益 ===' as section;
SELECT
  ndp.user_id,
  ROUND(SUM(CASE WHEN ndp.date >= '2025-12-15' AND ndp.date < '2026-01-01' THEN ndp.daily_profit ELSE 0 END)::numeric, 2) as "12月",
  ROUND(SUM(CASE WHEN ndp.date >= '2026-01-01' AND ndp.date < '2026-02-01' THEN ndp.daily_profit ELSE 0 END)::numeric, 2) as "1月",
  ROUND(SUM(CASE WHEN ndp.date >= '2026-02-01' THEN ndp.daily_profit ELSE 0 END)::numeric, 2) as "2月",
  ROUND(SUM(ndp.daily_profit)::numeric, 2) as "累計",
  ROUND(ac.available_usdt::numeric, 2) as "available_usdt"
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
JOIN affiliate_cycle ac ON ndp.user_id = ac.user_id
WHERE u.operation_start_date = '2025-12-15'
GROUP BY ndp.user_id, ac.available_usdt
ORDER BY SUM(ndp.daily_profit) ASC;

-- マイナスになっている12/15ユーザーの詳細
SELECT '=== マイナスの12/15ユーザー ===' as section;
SELECT
  ac.user_id,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = ac.user_id AND nm.buyback_date IS NULL) as nft_count,
  ROUND(ac.available_usdt::numeric, 2) as available_usdt,
  ROUND(ac.cum_usdt::numeric, 2) as cum_usdt,
  ac.phase
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE u.operation_start_date = '2025-12-15'
  AND ac.available_usdt < 0
ORDER BY ac.available_usdt;
