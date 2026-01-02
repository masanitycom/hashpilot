-- ========================================
-- 二重処理の最終確認
-- ========================================

-- 1. 12月1日に何が起きたか
SELECT '=== 1. 12月1日の処理ログ ===' as section;
SELECT
  date,
  created_at,
  total_profit_amount,
  distribution_dividend
FROM daily_yield_log_v2
WHERE date = '2025-12-01';

-- 2. 月次紹介報酬の詳細（2回の処理）
SELECT '=== 2. 月次紹介報酬: 12/1処理 vs 1/1処理 ===' as section;
SELECT
  CASE
    WHEN created_at < '2025-12-02' THEN '12/1処理'
    ELSE '1/1処理'
  END as processing_batch,
  COUNT(*) as record_count,
  SUM(profit_amount) as total_amount,
  COUNT(DISTINCT user_id) as unique_users
FROM user_referral_profit_monthly
GROUP BY CASE WHEN created_at < '2025-12-02' THEN '12/1処理' ELSE '1/1処理' END;

-- 3. 同一ユーザーに2回の紹介報酬があるか
SELECT '=== 3. 同一ユーザーへの二重紹介報酬 ===' as section;
SELECT
  user_id,
  COUNT(*) as record_count,
  SUM(profit_amount) as total_profit,
  array_agg(DISTINCT created_at::date) as processing_dates
FROM user_referral_profit_monthly
GROUP BY user_id
HAVING COUNT(DISTINCT created_at::date) > 1
LIMIT 20;

-- 4. 12月前半の日利合計（1NFTあたり）
SELECT '=== 4. 12月1日〜15日の日利（1NFT） ===' as section;
SELECT
  SUM(profit_per_nft * 0.42) as first_half_profit
FROM daily_yield_log_v2
WHERE date >= '2025-12-01' AND date <= '2025-12-15';

-- 5. 12月後半の日利合計（1NFTあたり）
SELECT '=== 5. 12月16日〜31日の日利（1NFT） ===' as section;
SELECT
  SUM(profit_per_nft * 0.42) as second_half_profit
FROM daily_yield_log_v2
WHERE date >= '2025-12-16' AND date <= '2025-12-31';

-- 6. 過剰額$23.912に近い期間を探す
SELECT '=== 6. $23.912に近い期間 ===' as section;
SELECT
  '12/1-12/15' as period,
  SUM(profit_per_nft * 0.42) as profit
FROM daily_yield_log_v2
WHERE date >= '2025-12-01' AND date <= '2025-12-15'
UNION ALL
SELECT
  '12/1-12/14' as period,
  SUM(profit_per_nft * 0.42) as profit
FROM daily_yield_log_v2
WHERE date >= '2025-12-01' AND date <= '2025-12-14'
UNION ALL
SELECT
  '12/1-12/31' as period,
  SUM(profit_per_nft * 0.42) as profit
FROM daily_yield_log_v2
WHERE date >= '2025-12-01' AND date <= '2025-12-31';

-- 7. 12月の月末処理が行われた日
SELECT '=== 7. 月末出金処理のタイミング ===' as section;
SELECT
  withdrawal_month,
  created_at,
  COUNT(*) as record_count
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01'
GROUP BY withdrawal_month, created_at
ORDER BY created_at
LIMIT 5;

-- 8. 紹介報酬がないユーザーの過剰額確認
-- 修正前の$47.32 = 日利$23.408 × 2
SELECT '=== 8. 紹介報酬なしユーザーの検証 ===' as section;
SELECT
  ac.user_id,
  ac.available_usdt,
  COALESCE(dp.total, 0) as daily_profit,
  COALESCE(rp.total, 0) as referral_profit,
  ac.available_usdt - COALESCE(dp.total, 0) - COALESCE(rp.total, 0) as diff
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
WHERE u.operation_start_date = '2025-12-01'
  AND COALESCE(rp.total, 0) = 0
ORDER BY ac.available_usdt DESC
LIMIT 10;
