-- daily_yield_logテーブルの構造確認
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_name = 'daily_yield_log' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 実際のデータ確認
SELECT 
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_by,
    created_at
FROM daily_yield_log 
ORDER BY date DESC
LIMIT 10;