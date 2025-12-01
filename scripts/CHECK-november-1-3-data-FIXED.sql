-- ========================================
-- 11月1日～3日のデータ確認（修正版）
-- ========================================

-- STEP 1: daily_yield_logテーブルの構造確認
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'daily_yield_log'
ORDER BY ordinal_position;
