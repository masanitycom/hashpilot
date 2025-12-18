-- ========================================
-- 11月出金完了ユーザーのavailable_usdtを一括修正
-- available_usdt = 12月の日利のみにリセット
-- ========================================

-- 修正前の件数確認
SELECT '【修正前】問題ユーザー数' as section;
SELECT COUNT(*) as count
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

-- 一括更新: available_usdt = 12月の日利のみ
UPDATE affiliate_cycle ac
SET available_usdt = COALESCE(dec.december_profit, 0)
FROM monthly_withdrawals mw
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as december_profit
  FROM nft_daily_profit
  WHERE date >= '2025-12-01'
  GROUP BY user_id
) dec ON mw.user_id = dec.user_id
WHERE ac.user_id = mw.user_id
  AND mw.withdrawal_month = '2025-11-01'
  AND mw.status = 'completed';

-- 修正後の確認
SELECT '【修正後】問題ユーザー数（0になるべき）' as section;
SELECT COUNT(*) as count
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

-- サンプル確認
SELECT '【サンプル】修正後のavailable_usdt' as section;
SELECT
  ac.user_id,
  ac.available_usdt,
  ac.phase
FROM affiliate_cycle ac
INNER JOIN monthly_withdrawals mw ON ac.user_id = mw.user_id
  AND mw.withdrawal_month = '2025-11-01'
  AND mw.status = 'completed'
ORDER BY ac.available_usdt DESC
LIMIT 10;
