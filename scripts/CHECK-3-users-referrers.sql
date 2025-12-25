-- 3ユーザーの紹介者を確認
SELECT
  u.user_id,
  u.email,
  u.referrer_user_id as level1_referrer,
  r1.email as level1_email,
  r1.referrer_user_id as level2_referrer,
  r2.email as level2_email,
  r2.referrer_user_id as level3_referrer,
  r3.email as level3_email
FROM users u
LEFT JOIN users r1 ON u.referrer_user_id = r1.user_id
LEFT JOIN users r2 ON r1.referrer_user_id = r2.user_id
LEFT JOIN users r3 ON r2.referrer_user_id = r3.user_id
WHERE u.user_id IN ('225F87', '20248A', '5A708D');
