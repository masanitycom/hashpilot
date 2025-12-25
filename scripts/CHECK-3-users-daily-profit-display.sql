-- ========================================
-- 3ユーザーの日次PNL表示確認
-- ダッシュボードで表示されるデータを確認
-- ========================================

-- 1. nft_daily_profitの12月データ（ダッシュボードのグラフ/履歴用）
SELECT
  user_id,
  date,
  daily_profit,
  base_amount
FROM nft_daily_profit
WHERE user_id IN ('225F87', '20248A', '5A708D')
  AND date >= '2025-12-01'
ORDER BY user_id, date;

-- 2. 各ユーザーの12月サマリー
SELECT
  user_id,
  COUNT(*) as total_days,
  MIN(date) as first_date,
  MAX(date) as last_date,
  SUM(daily_profit) as total_profit,
  SUM(CASE WHEN daily_profit > 0 THEN daily_profit ELSE 0 END) as positive_profit,
  SUM(CASE WHEN daily_profit < 0 THEN daily_profit ELSE 0 END) as negative_profit
FROM nft_daily_profit
WHERE user_id IN ('225F87', '20248A', '5A708D')
  AND date >= '2025-12-01'
GROUP BY user_id
ORDER BY user_id;

-- 3. ダッシュボードで使用されるビュー/クエリを確認
-- user_daily_profitビューがあるか確認
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_name LIKE '%daily%profit%'
ORDER BY table_name;

-- 4. user_daily_profitビューの定義確認（存在する場合）
SELECT pg_get_viewdef('user_daily_profit'::regclass, true) as view_definition;
