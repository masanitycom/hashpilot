-- テストに使えるユーザーを確認
-- 管理者アカウントを取得
SELECT user_id, email, coinw_uid
FROM users
WHERE email IN ('basarasystems@gmail.com', 'support@dshsupport.biz')
LIMIT 5;
