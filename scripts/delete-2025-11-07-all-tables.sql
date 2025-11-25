-- 2025/11/7のデータを全てのテーブルから削除

-- 1. nft_profit テーブルから削除（user_daily_profitビューの元データ）
DELETE FROM nft_profit
WHERE date = '2025-11-07';

-- 2. daily_yield_log テーブルから削除（既に削除済みの可能性あり）
DELETE FROM daily_yield_log
WHERE date = '2025-11-07';

-- 3. 削除確認
SELECT
  'nft_profit' as table_name,
  COUNT(*) as remaining_records
FROM nft_profit
WHERE date = '2025-11-07'
UNION ALL
SELECT
  'daily_yield_log' as table_name,
  COUNT(*) as remaining_records
FROM daily_yield_log
WHERE date = '2025-11-07'
UNION ALL
SELECT
  'user_daily_profit (ビュー)' as table_name,
  COUNT(*) as remaining_records
FROM user_daily_profit
WHERE date = '2025-11-07';
