-- ========================================
-- 6ユーザーの利益履歴を確認
-- operation_start_date = 2026-01-01 だが利益が出ているか？
-- ========================================

-- ========================================
-- 1. ユーザー基本情報
-- ========================================
SELECT '=== ユーザー基本情報 ===' as section;

SELECT
  user_id,
  email,
  operation_start_date,
  is_pegasus_exchange,
  created_at
FROM users
WHERE user_id IN ('A81A5E', '0F88DD', 'F733BD', '7DCFB7', 'DF623D', '2380A3')
ORDER BY user_id;

-- ========================================
-- 2. NFT情報
-- ========================================
SELECT '=== NFT情報 ===' as section;

SELECT
  user_id,
  id as nft_id,
  nft_type,
  acquired_date,
  buyback_date
FROM nft_master
WHERE user_id IN ('A81A5E', '0F88DD', 'F733BD', '7DCFB7', 'DF623D', '2380A3')
ORDER BY user_id, acquired_date;

-- ========================================
-- 3. nft_daily_profit（個人利益）履歴
-- ========================================
SELECT '=== 個人利益履歴（nft_daily_profit） ===' as section;

SELECT
  user_id,
  MIN(date) as first_profit_date,
  MAX(date) as last_profit_date,
  COUNT(*) as profit_days,
  SUM(daily_profit) as total_profit
FROM nft_daily_profit
WHERE user_id IN ('A81A5E', '0F88DD', 'F733BD', '7DCFB7', 'DF623D', '2380A3')
GROUP BY user_id
ORDER BY user_id;

-- ========================================
-- 4. 12月の個人利益詳細
-- ========================================
SELECT '=== 12月の個人利益詳細 ===' as section;

SELECT
  user_id,
  date,
  daily_profit
FROM nft_daily_profit
WHERE user_id IN ('A81A5E', '0F88DD', 'F733BD', '7DCFB7', 'DF623D', '2380A3')
  AND date >= '2025-12-01'
ORDER BY user_id, date;

-- ========================================
-- 5. affiliate_cycle状態
-- ========================================
SELECT '=== affiliate_cycle状態 ===' as section;

SELECT
  user_id,
  phase,
  cum_usdt,
  available_usdt,
  withdrawn_referral_usdt
FROM affiliate_cycle
WHERE user_id IN ('A81A5E', '0F88DD', 'F733BD', '7DCFB7', 'DF623D', '2380A3')
ORDER BY user_id;

-- ========================================
-- 6. monthly_withdrawals（出金履歴）
-- ========================================
SELECT '=== 出金履歴 ===' as section;

SELECT
  user_id,
  withdrawal_month,
  total_amount,
  personal_amount,
  referral_amount,
  status
FROM monthly_withdrawals
WHERE user_id IN ('A81A5E', '0F88DD', 'F733BD', '7DCFB7', 'DF623D', '2380A3')
ORDER BY user_id, withdrawal_month;

-- ========================================
-- 7. 紹介報酬履歴
-- ========================================
SELECT '=== 紹介報酬履歴（monthly_referral_profit） ===' as section;

SELECT
  user_id,
  year_month,
  SUM(profit_amount) as total_referral
FROM monthly_referral_profit
WHERE user_id IN ('A81A5E', '0F88DD', 'F733BD', '7DCFB7', 'DF623D', '2380A3')
GROUP BY user_id, year_month
ORDER BY user_id, year_month;
