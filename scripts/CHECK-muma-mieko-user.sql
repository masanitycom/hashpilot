-- muma.mieko@gmail.com を検索
SELECT user_id, email, is_pegasus_exchange
FROM users
WHERE email LIKE '%muma%' OR email LIKE '%mieko%';

-- 類似メールアドレスを検索
SELECT user_id, email
FROM users
WHERE email LIKE '%muma%'
   OR email LIKE '%mieko%'
   OR email LIKE '%mama%';
