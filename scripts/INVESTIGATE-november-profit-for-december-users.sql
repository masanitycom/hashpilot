-- ========================================
-- 12月開始ユーザーへの11月日利配布調査
-- ========================================
-- 問題: operation_start_date = 12月なのに11月の日利が配布された可能性
-- ========================================

-- 1. 12月開始ユーザーの11月日利（運用開始前なのに配布）
SELECT '=== 1. 12月開始ユーザーへの11月日利 ===' as section;
SELECT
  ndp.user_id,
  u.operation_start_date,
  ndp.date,
  SUM(ndp.daily_profit) as daily_total
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date >= '2025-12-01'
  AND ndp.date < '2025-12-01'
GROUP BY ndp.user_id, u.operation_start_date, ndp.date
ORDER BY ndp.user_id, ndp.date
LIMIT 100;

-- 2. ユーザー別: 11月日利の合計
SELECT '=== 2. ユーザー別: 運用開始前に配布された日利合計 ===' as section;
SELECT
  ndp.user_id,
  u.operation_start_date,
  SUM(ndp.daily_profit) as nov_profit_total,
  COUNT(DISTINCT ndp.date) as days_count
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date >= '2025-12-01'
  AND ndp.date < u.operation_start_date
GROUP BY ndp.user_id, u.operation_start_date
ORDER BY SUM(ndp.daily_profit) DESC;

-- 3. 過剰額との比較
SELECT '=== 3. 過剰額 = 運用開始前日利 の検証 ===' as section;
WITH pre_start_profit AS (
  SELECT
    ndp.user_id,
    SUM(ndp.daily_profit) as profit_before_start
  FROM nft_daily_profit ndp
  JOIN users u ON ndp.user_id = u.user_id
  WHERE u.operation_start_date >= '2025-12-01'
    AND ndp.date < u.operation_start_date
  GROUP BY ndp.user_id
),
over_amounts AS (
  SELECT
    ac.user_id,
    ac.available_usdt - (COALESCE(dp.total, 0) + COALESCE(rp.total, 0)) as over_amount
  FROM affiliate_cycle ac
  JOIN users u ON ac.user_id = u.user_id
  LEFT JOIN (
    SELECT user_id, SUM(daily_profit) as total
    FROM nft_daily_profit
    GROUP BY user_id
  ) dp ON ac.user_id = dp.user_id
  LEFT JOIN (
    SELECT user_id, SUM(profit_amount) as total
    FROM user_referral_profit_monthly
    GROUP BY user_id
  ) rp ON ac.user_id = rp.user_id
  WHERE u.operation_start_date >= '2025-12-01'
)
SELECT
  oa.user_id,
  ROUND(oa.over_amount, 2) as over_amount,
  ROUND(COALESCE(psp.profit_before_start, 0), 2) as profit_before_start,
  CASE
    WHEN ABS(oa.over_amount - COALESCE(psp.profit_before_start, 0)) < 1 THEN '✓ 一致'
    ELSE '❌ 不一致: ' || ROUND(oa.over_amount - COALESCE(psp.profit_before_start, 0), 2)::text
  END as match_status
FROM over_amounts oa
LEFT JOIN pre_start_profit psp ON oa.user_id = psp.user_id
WHERE ABS(oa.over_amount) > 1
ORDER BY oa.over_amount DESC;

-- 4. 全体統計
SELECT '=== 4. 影響の全体像 ===' as section;
SELECT
  COUNT(DISTINCT ndp.user_id) as affected_users,
  SUM(ndp.daily_profit) as total_incorrect_profit,
  COUNT(*) as total_incorrect_records
FROM nft_daily_profit ndp
JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date >= '2025-12-01'
  AND ndp.date < u.operation_start_date;
