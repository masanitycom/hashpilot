-- 2025/11/7のデータが残っているか確認

-- 1. daily_yield_logテーブルを確認
SELECT 'daily_yield_log' as source, *
FROM daily_yield_log
WHERE date = '2025-11-07';

-- 2. user_daily_profitビューを確認
SELECT 'user_daily_profit' as source, date, user_id, daily_profit
FROM user_daily_profit
WHERE date = '2025-11-07'
LIMIT 10;

-- 3. 11/7のデータ件数
SELECT
  'daily_yield_log' as table_name,
  COUNT(*) as record_count
FROM daily_yield_log
WHERE date = '2025-11-07'
UNION ALL
SELECT
  'user_daily_profit' as table_name,
  COUNT(*) as record_count
FROM user_daily_profit
WHERE date = '2025-11-07';
