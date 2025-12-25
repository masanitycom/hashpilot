-- ========================================
-- 6ユーザーの現在の状態確認（修正版）
-- ========================================

SELECT
  user_id,
  email,
  has_approved_nft,
  is_active_investor,
  operation_start_date,
  is_pegasus_exchange,
  total_purchases
FROM users
WHERE email IN (
  'msic200906@yahoo.co.jp',
  'oaiaiaio1226@gmail.com',
  'kyoko7oha@gmail.com',
  'miekohannsei@gmail.com',
  'sakanatsuri303@gmail.com',
  'yosshi.manmaru.oka1027@gmail.com'
)
ORDER BY email;
