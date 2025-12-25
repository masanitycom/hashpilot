-- ========================================
-- 6ユーザーを2026年1月1日から運用開始に設定
-- ========================================

-- 対象ユーザー確認
SELECT 'BEFORE' as status;
SELECT
  user_id,
  email,
  operation_start_date,
  is_pegasus_exchange
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

-- 更新
UPDATE users
SET
  is_pegasus_exchange = false,
  operation_start_date = '2026-01-01',
  updated_at = NOW()
WHERE email IN (
  'msic200906@yahoo.co.jp',
  'oaiaiaio1226@gmail.com',
  'kyoko7oha@gmail.com',
  'miekohannsei@gmail.com',
  'sakanatsuri303@gmail.com',
  'yosshi.manmaru.oka1027@gmail.com'
);

-- 更新後確認
SELECT 'AFTER' as status;
SELECT
  user_id,
  email,
  operation_start_date,
  is_pegasus_exchange,
  CASE
    WHEN operation_start_date > CURRENT_DATE THEN '⏳ 2026/1/1から運用開始'
    ELSE '✅ 運用中'
  END as status
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
