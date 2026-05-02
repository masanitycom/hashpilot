-- ========================================
-- 再試行後の状態確認
-- ========================================

-- 1) 現在の terms_agreed_at の値（NULLかどうか）
SELECT
  user_id,
  email,
  terms_agreed_at,
  EXTRACT(EPOCH FROM (NOW() - terms_agreed_at))/60 AS minutes_ago
FROM users
WHERE email IN ('motomi0101usp@gmail.com', 'motomi0101usp+2@gmail.com')
ORDER BY email;

-- 2) coinw_uid と関連状態（次に出るかもしれないポップアップの判定材料）
SELECT
  user_id,
  email,
  coinw_uid,
  channel_linked_confirmed,
  has_approved_nft,
  is_active_investor,
  terms_agreed_at
FROM users
WHERE email IN ('motomi0101usp@gmail.com', 'motomi0101usp+2@gmail.com')
ORDER BY email;
