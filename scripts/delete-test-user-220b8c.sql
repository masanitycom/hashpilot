-- テストユーザー220B8Cを完全削除

-- 1. usersテーブルから削除
DELETE FROM users WHERE user_id = '220B8C';

-- 2. auth.usersテーブルから削除
DELETE FROM auth.users WHERE email = 'masataka.tak+63@gmail.com';

-- 3. 関連するpurchasesがあれば削除
DELETE FROM purchases WHERE user_id = '220B8C';

-- 4. 現在のユーザー数確認
SELECT COUNT(*) as total_users FROM users;
