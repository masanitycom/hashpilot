-- CoinW UIDの登録状況を確認
SELECT 
  'CoinW UID登録状況' as check_type,
  COUNT(*) as total_users,
  COUNT(coinw_uid) as users_with_coinw_uid,
  COUNT(*) - COUNT(coinw_uid) as users_without_coinw_uid,
  ROUND(COUNT(coinw_uid) * 100.0 / COUNT(*), 2) as percentage_with_coinw_uid
FROM users;

-- 具体的なユーザー状況
SELECT 
  'ユーザー詳細' as check_type,
  user_id,
  email,
  coinw_uid,
  created_at,
  CASE 
    WHEN coinw_uid IS NOT NULL AND coinw_uid != '' THEN 'CoinW UID有り'
    ELSE 'CoinW UID無し'
  END as coinw_status
FROM users
ORDER BY created_at DESC
LIMIT 10;
