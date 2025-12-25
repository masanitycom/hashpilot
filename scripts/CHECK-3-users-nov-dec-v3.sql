-- ========================================
-- 3ユーザーの11月 vs 12月 日利配布比較
-- ========================================

-- 1. 3ユーザーの11月・12月の日利配布履歴
SELECT
  ndp.user_id,
  u.email,
  ndp.date,
  ndp.daily_profit,
  ndp.yield_rate,
  ndp.user_rate
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.user_id IN ('225F87', '20248A', '5A708D')
  AND ndp.date >= '2025-11-01'
ORDER BY u.email, ndp.date DESC;

-- 2. 11月と12月の配布日数カウント
SELECT
  u.user_id,
  u.email,
  SUM(CASE WHEN ndp.date >= '2025-11-01' AND ndp.date < '2025-12-01' THEN 1 ELSE 0 END) as november_count,
  SUM(CASE WHEN ndp.date >= '2025-12-01' THEN 1 ELSE 0 END) as december_count
FROM users u
LEFT JOIN nft_daily_profit ndp ON u.user_id = ndp.user_id
WHERE u.user_id IN ('225F87', '20248A', '5A708D')
GROUP BY u.user_id, u.email
ORDER BY u.email;

-- 3. 12月の日利設定状況（daily_yield_log_v2）
SELECT
  yield_date,
  total_pnl,
  profit_per_nft,
  created_at
FROM daily_yield_log_v2
WHERE yield_date >= '2025-12-01'
ORDER BY yield_date;

-- 4. 他のペガサスユーザーの12月配布状況
SELECT
  u.user_id,
  u.email,
  u.is_pegasus_exchange,
  COUNT(CASE WHEN ndp.date >= '2025-12-01' THEN 1 END) as december_profit_count,
  COUNT(CASE WHEN ndp.date >= '2025-11-01' AND ndp.date < '2025-12-01' THEN 1 END) as november_profit_count
FROM users u
LEFT JOIN nft_daily_profit ndp ON u.user_id = ndp.user_id
WHERE u.is_pegasus_exchange = true
GROUP BY u.user_id, u.email, u.is_pegasus_exchange
ORDER BY december_profit_count DESC, november_profit_count DESC;

-- 5. process_daily_yield_v2のペガサス除外条件確認
-- 関数定義を確認
SELECT prosrc
FROM pg_proc
WHERE proname = 'process_daily_yield_v2'
LIMIT 1;
