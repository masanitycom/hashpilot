-- purchasesテーブルの構造を確認
SELECT 'purchases table structure:' as info;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'purchases' 
ORDER BY ordinal_position;

-- usersテーブルの構造も確認
SELECT 'users table structure:' as info;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'users' 
ORDER BY ordinal_position;

-- 実際のpurchasesデータを確認
SELECT 'Sample purchases data:' as info;
SELECT * FROM purchases LIMIT 3;
