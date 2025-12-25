-- ========================================
-- 6ユーザーの現在の状態確認
-- 2026年1月1日から運用開始予定
-- ========================================

SELECT
  user_id,
  email,
  has_approved_nft,
  is_active_investor,
  operation_start_date,
  is_pegasus_exchange,
  total_purchases,
  created_at
FROM users
WHERE email IN (
  'msic200906@yahoo.co.jp',
  'oaiaiaio1226@gmail.com',
  'kyoko7oha@gmail.com',
  'muma.mieko@gmail.com',
  'sakanatsuri303@gmail.com',
  'yosshi.manmaru.oka1027@gmail.com'
)
ORDER BY email;

-- NFT保有状況
SELECT
  u.user_id,
  u.email,
  COUNT(nm.id) as nft_count
FROM users u
LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
WHERE u.email IN (
  'msic200906@yahoo.co.jp',
  'oaiaiaio1226@gmail.com',
  'kyoko7oha@gmail.com',
  'muma.mieko@gmail.com',
  'sakanatsuri303@gmail.com',
  'yosshi.manmaru.oka1027@gmail.com'
)
GROUP BY u.user_id, u.email
ORDER BY u.email;
