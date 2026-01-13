-- ========================================
-- 日次紹介報酬が発生しなくなっているか確認
-- 実行日: 2026-01-13
-- ========================================

-- 1. user_referral_profitテーブルの現在の状態
SELECT '=== user_referral_profit テーブル状態 ===' as section;

SELECT
  COUNT(*) as total_records,
  COUNT(DISTINCT user_id) as unique_users,
  MIN(date) as oldest_date,
  MAX(date) as newest_date
FROM user_referral_profit;

-- 2. 月別の件数（どの時期にデータがあるか）
SELECT '=== 月別レコード数 ===' as section;

SELECT
  TO_CHAR(date, 'YYYY-MM') as year_month,
  COUNT(*) as records,
  SUM(profit_amount) as total_amount
FROM user_referral_profit
GROUP BY TO_CHAR(date, 'YYYY-MM')
ORDER BY year_month DESC
LIMIT 12;

-- 3. 直近7日間のデータ（新規作成されていないか）
SELECT '=== 直近7日間のデータ ===' as section;

SELECT
  date,
  COUNT(*) as records,
  SUM(profit_amount) as total_amount
FROM user_referral_profit
WHERE date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY date
ORDER BY date DESC;

-- 4. 今日のデータ
SELECT '=== 今日のデータ ===' as section;

SELECT
  CASE WHEN COUNT(*) = 0 THEN '✅ 今日の日次紹介報酬: なし（正常）'
       ELSE '⚠️ 今日の日次紹介報酬: ' || COUNT(*) || '件（異常）'
  END as status
FROM user_referral_profit
WHERE date = CURRENT_DATE;
