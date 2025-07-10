-- daily_yield_logテーブルの実際のデータを確認

-- 1. daily_yield_logの全データ表示
SELECT 
  'All daily_yield_log data' as info,
  id,
  date,
  yield_rate,
  margin_rate,
  user_rate,
  is_month_end,
  created_at
FROM daily_yield_log 
ORDER BY date DESC, created_at DESC;

-- 2. 日付のフォーマット確認
SELECT 
  'Date format check' as info,
  date,
  date::text as date_text,
  to_char(date, 'YYYY-MM-DD') as formatted_date,
  created_at
FROM daily_yield_log 
ORDER BY date DESC;

-- 3. 今日の日付で日利設定を作成する必要があるか確認
SELECT 
  'Today and yesterday dates' as info,
  CURRENT_DATE as today,
  CURRENT_DATE - INTERVAL '1 day' as yesterday,
  CURRENT_DATE - INTERVAL '2 days' as two_days_ago;