-- テーブル構造の詳細確認

-- usersテーブルの構造
SELECT 'Users table structure:' as info;
SELECT 
  column_name, 
  data_type, 
  character_maximum_length,
  column_default,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'users' 
ORDER BY ordinal_position;

-- purchasesテーブルの構造
SELECT 'Purchases table structure:' as info;
SELECT 
  column_name, 
  data_type, 
  character_maximum_length,
  column_default,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'purchases' 
ORDER BY ordinal_position;

-- adminsテーブルの構造
SELECT 'Admins table structure:' as info;
SELECT 
  column_name, 
  data_type, 
  character_maximum_length,
  column_default,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'admins' 
ORDER BY ordinal_position;

-- 実際のデータサンプル
SELECT 'Sample data from users:' as info;
SELECT user_id, email, full_name, has_approved_nft 
FROM users 
LIMIT 3;

SELECT 'Sample data from purchases:' as info;
SELECT id, user_id, payment_status, admin_approved, amount_usd 
FROM purchases 
LIMIT 3;
