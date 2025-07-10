-- daily_yield_logテーブルの構造とデータ確認

-- 1. テーブル構造確認
SELECT 
  'daily_yield_log structure' as info,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns 
WHERE table_name = 'daily_yield_log' 
ORDER BY ordinal_position;

-- 2. 実際のデータ確認
SELECT 
  'daily_yield_log data' as info,
  *
FROM daily_yield_log 
ORDER BY date DESC
LIMIT 10;

-- 3. user_daily_profitテーブルの確認
SELECT 
  'user_daily_profit count by date' as info,
  date,
  COUNT(*) as user_count,
  SUM(daily_profit) as total_profit
FROM user_daily_profit 
GROUP BY date
ORDER BY date DESC;

-- 4. 7/8の日利設定に基づいてuser_daily_profitデータがあるかチェック
SELECT 
  'profit data for 2025-07-08' as info,
  COUNT(*) as user_count,
  SUM(daily_profit) as total_profit,
  AVG(daily_profit) as avg_profit
FROM user_daily_profit 
WHERE date = '2025-07-08';