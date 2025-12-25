-- ========================================
-- テスト用CoinW UID変更申請を作成
-- basarasystems@gmail.com 宛にメール送信テスト
-- ========================================

-- 1. ユーザー確認
SELECT user_id, email, coinw_uid
FROM users
WHERE email = 'basarasystems@gmail.com';

-- 2. テスト用申請を作成
INSERT INTO coinw_uid_changes (
  id,
  user_id,
  old_coinw_uid,
  new_coinw_uid,
  status,
  created_at
)
SELECT
  gen_random_uuid(),
  user_id,
  coinw_uid,
  'TEST123456789',
  'pending',
  NOW()
FROM users
WHERE email = 'basarasystems@gmail.com';

-- 3. 作成確認
SELECT 
  c.id,
  c.user_id,
  u.email,
  c.old_coinw_uid,
  c.new_coinw_uid,
  c.status,
  c.created_at
FROM coinw_uid_changes c
JOIN users u ON c.user_id = u.user_id
WHERE u.email = 'basarasystems@gmail.com'
  AND c.status = 'pending'
ORDER BY c.created_at DESC
LIMIT 1;
