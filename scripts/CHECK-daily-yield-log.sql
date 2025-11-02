-- daily_yield_logテーブルの最新データを確認

SELECT '【最新10件の日利設定】' as info;
SELECT date, yield_rate, margin_rate, user_rate, created_at
FROM daily_yield_log
ORDER BY date DESC
LIMIT 10;

SELECT '【11/1のデータ確認】' as info;
SELECT date, yield_rate, margin_rate, user_rate, created_at
FROM daily_yield_log
WHERE date = '2025-11-01';

SELECT '【総レコード数】' as info;
SELECT COUNT(*) as total_records
FROM daily_yield_log;
