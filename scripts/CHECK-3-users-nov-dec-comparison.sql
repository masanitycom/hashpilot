-- ========================================
-- 3ユーザーの11月 vs 12月 日利配布比較
-- ========================================

-- 1. nft_daily_profitテーブルのカラム確認
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'nft_daily_profit'
ORDER BY ordinal_position;

-- 2. 11月と12月の日利配布状況
SELECT
  ndp.user_id,
  u.email,
  DATE(ndp.created_at) as profit_date,
  ndp.nft_count,
  ndp.total_profit
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.user_id IN ('225F87', '20248A', '5A708D')
ORDER BY u.email, ndp.created_at DESC
LIMIT 50;

-- 3. 12月の日利設定状況（daily_yield_log_v2）
SELECT
  yield_date,
  total_pnl,
  profit_per_nft,
  created_at
FROM daily_yield_log_v2
WHERE yield_date >= '2025-12-01'
ORDER BY yield_date;

-- 4. ペガサスユーザー全体の12月日利配布状況
SELECT
  u.user_id,
  u.email,
  u.is_pegasus_exchange,
  COUNT(ndp.id) as december_profit_count
FROM users u
LEFT JOIN nft_daily_profit ndp ON u.user_id = ndp.user_id
  AND ndp.created_at >= '2025-12-01'
WHERE u.is_pegasus_exchange = true
GROUP BY u.user_id, u.email, u.is_pegasus_exchange
ORDER BY december_profit_count DESC;
