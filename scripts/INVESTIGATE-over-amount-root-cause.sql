-- ========================================
-- 過剰加算の原因特定調査
-- ========================================
-- 目的: なぜ12月開始ユーザーのavailable_usdtが過大なのか
-- ========================================

-- 調査1: ACACDBの詳細（最も差額が大きい）
SELECT '=== 1. ACACDB: 日利履歴全件 ===' as section;
SELECT
  date,
  daily_profit
FROM nft_daily_profit
WHERE user_id = 'ACACDB'
ORDER BY date;

-- 調査2: ACACDBの紹介報酬履歴
SELECT '=== 2. ACACDB: 紹介報酬履歴 ===' as section;
SELECT
  profit_month,
  profit_amount,
  created_at
FROM user_referral_profit_monthly
WHERE user_id = 'ACACDB'
ORDER BY profit_month;

-- 調査3: affiliate_cycleの更新履歴（updated_atで推測）
SELECT '=== 3. ACACDB: affiliate_cycle現在値 ===' as section;
SELECT
  user_id,
  available_usdt,
  cum_usdt,
  phase,
  created_at,
  updated_at
FROM affiliate_cycle
WHERE user_id = 'ACACDB';

-- 調査4: 11月の日利が存在するか確認（運用開始前なのに）
SELECT '=== 4. 12月開始ユーザーの11月日利（あってはならない） ===' as section;
SELECT
  ndp.user_id,
  u.operation_start_date,
  ndp.date,
  ndp.daily_profit,
  CASE
    WHEN ndp.date < u.operation_start_date THEN '❌ 運用開始前に配布'
    ELSE '✓ 正常'
  END as status
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date >= '2025-12-01'
  AND ndp.date < u.operation_start_date
ORDER BY ndp.user_id, ndp.date
LIMIT 50;

-- 調査5: 11月日利の合計（運用開始前のユーザー分）
SELECT '=== 5. 運用開始前に配布された日利の合計 ===' as section;
SELECT
  ndp.user_id,
  u.operation_start_date,
  SUM(ndp.daily_profit) as nov_profit_before_start,
  COUNT(*) as record_count
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date >= '2025-12-01'
  AND ndp.date < u.operation_start_date
GROUP BY ndp.user_id, u.operation_start_date
ORDER BY SUM(ndp.daily_profit) DESC;

-- 調査6: over_amountと11月日利の比較
SELECT '=== 6. 過剰額 vs 運用開始前日利 ===' as section;
WITH dec_users AS (
  SELECT
    ac.user_id,
    u.operation_start_date,
    ac.available_usdt as current_available,
    COALESCE(dp.total_profit, 0) + COALESCE(rp.total_referral, 0) as correct_available
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
  WHERE u.operation_start_date >= '2025-12-01'
),
pre_start_profit AS (
  SELECT
    ndp.user_id,
    SUM(ndp.daily_profit) as profit_before_start
  FROM nft_daily_profit ndp
  JOIN users u ON ndp.user_id = u.user_id
  WHERE u.operation_start_date >= '2025-12-01'
    AND ndp.date < u.operation_start_date
  GROUP BY ndp.user_id
)
SELECT
  du.user_id,
  du.operation_start_date,
  du.current_available - du.correct_available as over_amount,
  COALESCE(psp.profit_before_start, 0) as profit_before_start,
  ROUND((du.current_available - du.correct_available) - COALESCE(psp.profit_before_start, 0), 3) as remaining_diff
FROM dec_users du
LEFT JOIN pre_start_profit psp ON du.user_id = psp.user_id
WHERE du.current_available - du.correct_available > 1
ORDER BY du.current_available - du.correct_available DESC;

-- 調査7: daily_yield_logで11月の日利設定を確認
SELECT '=== 7. 11月の日利設定履歴 ===' as section;
SELECT
  date,
  yield_rate,
  margin_rate,
  user_rate,
  created_at
FROM daily_yield_log
WHERE date >= '2025-11-01' AND date < '2025-12-01'
ORDER BY date DESC
LIMIT 10;

-- 調査8: V2テーブルの日利設定
SELECT '=== 8. daily_yield_log_v2の履歴 ===' as section;
SELECT
  date,
  daily_pnl,
  profit_per_nft,
  created_at
FROM daily_yield_log_v2
ORDER BY date DESC
LIMIT 10;
