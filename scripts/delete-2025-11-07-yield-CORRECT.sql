-- 2025/11/7の日利データを削除（正しい方法）

-- 元のテーブル: daily_yield_log から削除
DELETE FROM daily_yield_log
WHERE date = '2025-11-07';

-- 確認クエリ
SELECT
  'daily_yield_log' as table_name,
  COUNT(*) as remaining_records
FROM daily_yield_log
WHERE date = '2025-11-07';

-- user_daily_profitビューで確認（自動的に更新される）
SELECT
  'user_daily_profit (ビュー)' as view_name,
  COUNT(*) as remaining_records
FROM user_daily_profit
WHERE date = '2025-11-07';
