-- 管理者ユーザーを確認

-- adminsテーブルから管理者を確認
SELECT
  user_id,
  email,
  role,
  created_at
FROM admins
ORDER BY created_at;

-- usersテーブルでメールアドレスから確認
SELECT
  user_id,
  email,
  username,
  has_approved_nft,
  total_purchases,
  created_at
FROM users
WHERE email IN (
  'basarasystems@gmail.com',
  'support@dshsupport.biz'
)
ORDER BY created_at;

-- 2BF53Bのユーザー情報
SELECT
  user_id,
  email,
  username,
  has_approved_nft,
  total_purchases,
  created_at
FROM users
WHERE user_id = '2BF53B';

-- 7A9637のユーザー情報
SELECT
  user_id,
  email,
  username,
  has_approved_nft,
  total_purchases,
  created_at
FROM users
WHERE user_id = '7A9637';
