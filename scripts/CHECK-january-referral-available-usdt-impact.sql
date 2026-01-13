-- ========================================
-- 1月の日次紹介報酬がavailable_usdtに影響しているか確認
-- 実行日: 2026-01-13
-- ========================================

-- 1. user_referral_profitの1月データがavailable_usdtに加算されているか確認
-- available_usdtには日次利益 + 紹介報酬（USDTフェーズ分）が含まれる

SELECT '=== 1月の日次紹介報酬データ概要 ===' as section;

SELECT
  COUNT(*) as total_records,
  COUNT(DISTINCT user_id) as affected_users,
  SUM(profit_amount) as total_incorrect_referral,
  MIN(date) as min_date,
  MAX(date) as max_date
FROM user_referral_profit
WHERE date >= '2026-01-01';

-- 2. 上位10ユーザーの詳細（cum_usdtとの差分確認）
SELECT '=== 上位影響ユーザー（日次紹介報酬 vs monthly_referral_profit差分） ===' as section;

SELECT
  urp.user_id,
  urp.jan_daily_total as "1月日次紹介報酬",
  COALESCE(mrp.total_monthly, 0) as "月次紹介報酬累計",
  ac.cum_usdt as "現在のcum_usdt",
  ac.available_usdt as "現在のavailable_usdt",
  ac.phase
FROM (
  SELECT user_id, SUM(profit_amount) as jan_daily_total
  FROM user_referral_profit
  WHERE date >= '2026-01-01'
  GROUP BY user_id
) urp
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_monthly
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON urp.user_id = mrp.user_id
LEFT JOIN affiliate_cycle ac ON urp.user_id = ac.user_id
ORDER BY urp.jan_daily_total DESC
LIMIT 15;

-- 3. 59C23Cの詳細確認
SELECT '=== 59C23C 詳細 ===' as section;

SELECT
  '日次紹介報酬（1月）' as data_type,
  SUM(profit_amount) as amount
FROM user_referral_profit
WHERE user_id = '59C23C' AND date >= '2026-01-01'
UNION ALL
SELECT
  '月次紹介報酬（累計）' as data_type,
  SUM(profit_amount) as amount
FROM monthly_referral_profit
WHERE user_id = '59C23C'
UNION ALL
SELECT
  'cum_usdt（現在）' as data_type,
  cum_usdt as amount
FROM affiliate_cycle
WHERE user_id = '59C23C'
UNION ALL
SELECT
  'available_usdt（現在）' as data_type,
  available_usdt as amount
FROM affiliate_cycle
WHERE user_id = '59C23C';

-- 4. 日次紹介報酬がcum_usdtに加算されているか判定
-- monthly_referral_profitの合計とcum_usdtを比較
SELECT '=== cum_usdtとmonthly_referral_profitの整合性確認 ===' as section;

SELECT
  CASE
    WHEN ABS(ac.cum_usdt - COALESCE(mrp.total, 0)) < 0.01 THEN '✅ 一致（日次データは加算されていない）'
    WHEN ac.cum_usdt > COALESCE(mrp.total, 0) THEN '⚠️ cum_usdtが大きい（日次データが加算された可能性）'
    ELSE '⚠️ cum_usdtが小さい（NFT付与で減算済み）'
  END as status,
  COUNT(*) as user_count
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ac.user_id IN (SELECT DISTINCT user_id FROM user_referral_profit WHERE date >= '2026-01-01')
GROUP BY
  CASE
    WHEN ABS(ac.cum_usdt - COALESCE(mrp.total, 0)) < 0.01 THEN '✅ 一致（日次データは加算されていない）'
    WHEN ac.cum_usdt > COALESCE(mrp.total, 0) THEN '⚠️ cum_usdtが大きい（日次データが加算された可能性）'
    ELSE '⚠️ cum_usdtが小さい（NFT付与で減算済み）'
  END;
