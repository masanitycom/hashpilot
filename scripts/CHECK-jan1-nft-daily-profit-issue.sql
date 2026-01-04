-- ========================================
-- 1/1のnft_daily_profit問題調査
-- ========================================

-- 1. 重複レコードの確認
SELECT '=== 重複レコード確認 ===' as section;
SELECT
  user_id,
  date,
  COUNT(*) as record_count,
  SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE date = '2026-01-01'
GROUP BY user_id, date
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC
LIMIT 20;

-- 2. テーブル構造確認
SELECT '=== nft_daily_profitテーブル構造 ===' as section;
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'nft_daily_profit'
ORDER BY ordinal_position;

-- 3. 1/1のレコード総数
SELECT '=== 1/1レコード総数 ===' as section;
SELECT COUNT(*) as total_records FROM nft_daily_profit WHERE date = '2026-01-01';

-- 4. ユニークユーザー数
SELECT '=== 1/1ユニークユーザー数 ===' as section;
SELECT COUNT(DISTINCT user_id) as unique_users FROM nft_daily_profit WHERE date = '2026-01-01';

-- 5. 02FDF0の詳細
SELECT '=== 02FDF0の1/1レコード詳細 ===' as section;
SELECT * FROM nft_daily_profit WHERE user_id = '02FDF0' AND date = '2026-01-01';
