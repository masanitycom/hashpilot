-- 2025/11/7の日利データを削除

-- 1. user_daily_profitテーブルから削除
DELETE FROM user_daily_profit
WHERE date = '2025-11-07';

-- 2. yield_historyテーブルから削除（存在する場合）
DELETE FROM yield_history
WHERE date = '2025-11-07';

-- 確認
SELECT 'user_daily_profit削除完了' as status, COUNT(*) as remaining_records
FROM user_daily_profit
WHERE date = '2025-11-07';
