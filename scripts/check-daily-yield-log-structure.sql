-- daily_yield_logテーブルの構造を確認
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'daily_yield_log' 
    AND table_schema = 'public'
ORDER BY ordinal_position;

-- 実際のデータも確認
SELECT * FROM daily_yield_log ORDER BY date DESC LIMIT 5;
