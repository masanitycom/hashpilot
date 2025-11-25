-- ========================================
-- ユーザーJ77883の紹介報酬履歴を確認
-- ========================================
-- 実行環境: 本番環境 Supabase SQL Editor
-- ========================================

-- 今月（11月）の紹介報酬詳細
SELECT
  date,
  referral_level,
  child_user_id,
  profit_amount,
  created_at
FROM user_referral_profit
WHERE user_id = 'J77883'
  AND date >= '2025-11-01'
  AND date <= '2025-11-30'
ORDER BY date DESC, referral_level;

-- 今月の合計
SELECT
  referral_level,
  COUNT(*) as count,
  SUM(profit_amount) as total_amount
FROM user_referral_profit
WHERE user_id = 'J77883'
  AND date >= '2025-11-01'
  AND date <= '2025-11-30'
GROUP BY referral_level
ORDER BY referral_level;

-- 全期間の合計
SELECT
  referral_level,
  COUNT(*) as count,
  SUM(profit_amount) as total_amount
FROM user_referral_profit
WHERE user_id = 'J77883'
GROUP BY referral_level
ORDER BY referral_level;

-- このユーザーの直接紹介者
SELECT
  user_id,
  full_name,
  operation_start_date,
  has_approved_nft
FROM users
WHERE referrer_user_id = 'J77883'
ORDER BY created_at;

-- affiliate_cycleの状態
SELECT
  user_id,
  cum_usdt,
  available_usdt,
  total_nft_count,
  auto_nft_count,
  manual_nft_count,
  phase
FROM affiliate_cycle
WHERE user_id = 'J77883';
