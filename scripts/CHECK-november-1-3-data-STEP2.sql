-- ========================================
-- STEP 2: 11月1日～3日のデータ確認
-- ========================================

-- daily_yield_logテーブルの全カラム取得
SELECT *
FROM daily_yield_log
WHERE date >= '2025-11-01' AND date <= '2025-11-03'
ORDER BY date;
