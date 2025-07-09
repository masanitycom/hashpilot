-- usersテーブルの構造を確認

-- 1. テーブルの列を確認
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'users'
ORDER BY ordinal_position;

-- 2. 実際のユーザーデータを確認（最初の5行）
SELECT id, user_id, email, full_name, coinw_uid, created_at, total_purchases
FROM users
ORDER BY created_at DESC
LIMIT 5;

-- 3. 特定のUUIDがあるかどうか確認
SELECT id, user_id, email, full_name
FROM users
WHERE id = '7241f7f8-d05f-4c62-ac32-c2f8d8a93323'
OR user_id = '7241f7f8-d05f-4c62-ac32-c2f8d8a93323';

-- 4. user_idがUUIDかTextかを確認
SELECT 
    pg_typeof(id) as id_type,
    pg_typeof(user_id) as user_id_type,
    LENGTH(user_id) as user_id_length
FROM users
LIMIT 1;