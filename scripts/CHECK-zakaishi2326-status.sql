-- ========================================
-- zakaishi2326@gmail.com ユーザー状況確認
-- ========================================

-- 1. ユーザー基本情報
SELECT '=== 1. ユーザー基本情報 ===' as section;
SELECT
  id,
  user_id,
  email,
  full_name,
  has_approved_nft,
  operation_start_date,
  is_active_investor,
  is_pegasus_exchange,
  total_purchases,
  created_at
FROM users
WHERE email = 'zakaishi2326@gmail.com';

-- 2. NFT保有状況
SELECT '=== 2. NFT保有状況 ===' as section;
SELECT
  id,
  user_id,
  nft_type,
  acquired_date,
  operation_start_date,
  buyback_date
FROM nft_master
WHERE user_id = (SELECT user_id FROM users WHERE email = 'zakaishi2326@gmail.com')
ORDER BY acquired_date;

-- 3. affiliate_cycle状況
SELECT '=== 3. affiliate_cycle状況 ===' as section;
SELECT
  user_id,
  available_usdt,
  cum_usdt,
  withdrawn_referral_usdt,
  phase,
  auto_nft_count,
  manual_nft_count,
  total_nft_count
FROM affiliate_cycle
WHERE user_id = (SELECT user_id FROM users WHERE email = 'zakaishi2326@gmail.com');

-- 4. 1月の日利履歴
SELECT '=== 4. 2026年1月 日利履歴 ===' as section;
SELECT
  date,
  daily_profit,
  nft_count
FROM nft_daily_profit
WHERE user_id = (SELECT user_id FROM users WHERE email = 'zakaishi2326@gmail.com')
  AND date >= '2026-01-01' AND date <= '2026-01-31'
ORDER BY date;

-- 5. 2月の日利履歴
SELECT '=== 5. 2026年2月 日利履歴 ===' as section;
SELECT
  date,
  daily_profit,
  nft_count
FROM nft_daily_profit
WHERE user_id = (SELECT user_id FROM users WHERE email = 'zakaishi2326@gmail.com')
  AND date >= '2026-02-01'
ORDER BY date;

-- 6. 月末出金レコード
SELECT '=== 6. 月末出金レコード ===' as section;
SELECT
  withdrawal_month,
  personal_amount,
  referral_amount,
  total_amount,
  status,
  task_completed
FROM monthly_withdrawals
WHERE user_id = (SELECT user_id FROM users WHERE email = 'zakaishi2326@gmail.com')
ORDER BY withdrawal_month;

-- 7. タスク完了状況
SELECT '=== 7. タスク完了状況 ===' as section;
SELECT
  user_id,
  year_month,
  is_completed,
  completed_at
FROM monthly_reward_tasks
WHERE user_id = (SELECT user_id FROM users WHERE email = 'zakaishi2326@gmail.com')
ORDER BY year_month;

-- 8. 購入履歴
SELECT '=== 8. 購入履歴 ===' as section;
SELECT
  id,
  amount_usd,
  admin_approved,
  approved_at,
  created_at
FROM purchases
WHERE user_id = (SELECT user_id FROM users WHERE email = 'zakaishi2326@gmail.com')
ORDER BY created_at;
