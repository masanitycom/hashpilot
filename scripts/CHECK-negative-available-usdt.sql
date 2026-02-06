-- ========================================
-- available_usdtがマイナスのユーザーを調査
-- ========================================

-- STEP 1: マイナスのユーザー一覧
SELECT '=== マイナスavailable_usdtのユーザー ===' as section;
SELECT 
  ac.user_id,
  ac.available_usdt,
  ac.cum_usdt,
  ac.phase,
  ac.auto_nft_count,
  ac.withdrawn_referral_usdt
FROM affiliate_cycle ac
WHERE ac.available_usdt < 0
ORDER BY ac.available_usdt ASC;

-- STEP 2: 全体統計
SELECT '=== 全体統計 ===' as section;
SELECT 
  COUNT(*) as total_users,
  COUNT(*) FILTER (WHERE available_usdt < 0) as negative_count,
  COUNT(*) FILTER (WHERE available_usdt >= 0) as positive_count,
  SUM(available_usdt) as total_available_usdt,
  MIN(available_usdt) as min_available_usdt,
  MAX(available_usdt) as max_available_usdt
FROM affiliate_cycle;

-- STEP 3: サンプルユーザーの詳細（最もマイナスが大きいユーザー）
SELECT '=== 最もマイナスが大きいユーザーの内訳 ===' as section;
WITH worst_user AS (
  SELECT user_id FROM affiliate_cycle ORDER BY available_usdt ASC LIMIT 1
)
SELECT
  ac.user_id,
  ac.available_usdt as "available_usdt",
  COALESCE(dp.total_daily_profit, 0) as "日利合計",
  COALESCE(rp.total_referral, 0) as "紹介報酬合計",
  COALESCE(w.total_withdrawn, 0) as "出金合計",
  ac.withdrawn_referral_usdt as "出金済み紹介報酬"
FROM affiliate_cycle ac
JOIN worst_user wu ON ac.user_id = wu.user_id
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total_daily_profit
  FROM nft_daily_profit
  GROUP BY user_id
) dp ON ac.user_id = dp.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  GROUP BY user_id
) rp ON ac.user_id = rp.user_id
LEFT JOIN (
  SELECT user_id, SUM(total_amount) as total_withdrawn
  FROM monthly_withdrawals
  WHERE status = 'completed'
  GROUP BY user_id
) w ON ac.user_id = w.user_id;

-- STEP 4: available_usdtの計算式確認
-- 理論上: available_usdt = 日利合計 + 紹介報酬（USDTフェーズ分のみ） - 出金合計
