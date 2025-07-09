-- purchasesテーブルの構造を確認
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'purchases' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 実際のデータも確認
SELECT user_id, pg_typeof(user_id) as user_id_type
FROM purchases 
LIMIT 1;
