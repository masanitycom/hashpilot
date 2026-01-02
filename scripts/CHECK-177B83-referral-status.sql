-- ========================================
-- 177B83 紹介報酬ステータス確認
-- ========================================

-- 1. ユーザー情報
SELECT '=== 1. ユーザー情報 ===' as section;
SELECT
  user_id,
  email,
  total_purchases,
  operation_start_date
FROM users
WHERE user_id = '177B83';

-- 2. affiliate_cycle（サイクル状態）
SELECT '=== 2. affiliate_cycle ===' as section;
SELECT
  user_id,
  cum_usdt,
  available_usdt,
  phase,
  auto_nft_count,
  manual_nft_count
FROM affiliate_cycle
WHERE user_id = '177B83';

-- 3. 月次紹介報酬
SELECT '=== 3. 月次紹介報酬 ===' as section;
SELECT
  year,
  month,
  referral_level,
  child_user_id,
  profit_amount,
  created_at
FROM user_referral_profit_monthly
WHERE user_id = '177B83'
ORDER BY created_at, referral_level;

-- 4. 紹介報酬合計
SELECT '=== 4. 紹介報酬合計 ===' as section;
SELECT
  SUM(profit_amount) as total_referral,
  COUNT(*) as record_count
FROM user_referral_profit_monthly
WHERE user_id = '177B83';

-- 5. 日利合計
SELECT '=== 5. 日利合計 ===' as section;
SELECT
  SUM(daily_profit) as total_daily_profit
FROM nft_daily_profit
WHERE user_id = '177B83';

-- 6. フェーズ計算の確認
-- cum_usdt >= 1100 → HOLD（ロック）
-- cum_usdt < 1100 → USDT（払い出し可能）
SELECT '=== 6. フェーズ計算 ===' as section;
SELECT
  cum_usdt,
  CASE
    WHEN cum_usdt >= 1100 THEN 'HOLD（ロック中）'
    ELSE 'USDT（払い出し可能）'
  END as phase_status,
  CASE
    WHEN cum_usdt >= 1100 THEN cum_usdt - 1100
    ELSE 0
  END as locked_amount,
  CASE
    WHEN cum_usdt < 1100 THEN cum_usdt
    ELSE 0
  END as available_referral
FROM affiliate_cycle
WHERE user_id = '177B83';

-- 7. 出金レコード
SELECT '=== 7. 月末出金レコード ===' as section;
SELECT
  withdrawal_month,
  total_amount,
  personal_amount,
  referral_amount,
  status
FROM monthly_withdrawals
WHERE user_id = '177B83'
ORDER BY withdrawal_month;
