-- ========================================
-- 59C23C, 177B83 の available_usdt 修正
-- ========================================
-- 問題: 1月日利調整でavailable_usdtが更新されていない
-- ========================================

-- STEP 1: 現在の状態
SELECT '=== STEP 1: 現在の状態 ===' as section;
SELECT 
  ac.user_id,
  ac.available_usdt as 現在のavailable,
  ac.cum_usdt,
  ac.withdrawn_referral_usdt,
  ac.auto_nft_count
FROM affiliate_cycle ac
WHERE ac.user_id IN ('59C23C', '177B83');

-- STEP 2: 正しいavailable_usdtを計算
-- available = 全期間個人利益 
--           + 出金済み紹介報酬 
--           + NFT自動付与分($1100) 
--           - 出金済み合計
SELECT '=== STEP 2: 正しい値を計算 ===' as section;
WITH profit_sum AS (
  SELECT user_id, SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  WHERE user_id IN ('59C23C', '177B83')
  GROUP BY user_id
),
withdrawal_sum AS (
  SELECT user_id, SUM(total_amount) as total_withdrawn
  FROM monthly_withdrawals
  WHERE user_id IN ('59C23C', '177B83')
    AND status = 'completed'
  GROUP BY user_id
)
SELECT 
  ac.user_id,
  ROUND((ps.total_profit + ac.withdrawn_referral_usdt + (ac.auto_nft_count * 1100) - COALESCE(ws.total_withdrawn, 0))::numeric, 2) as 正しいavailable
FROM affiliate_cycle ac
LEFT JOIN profit_sum ps ON ac.user_id = ps.user_id
LEFT JOIN withdrawal_sum ws ON ac.user_id = ws.user_id
WHERE ac.user_id IN ('59C23C', '177B83');

-- STEP 3: available_usdtを修正
SELECT '=== STEP 3: available_usdtを修正 ===' as section;
WITH profit_sum AS (
  SELECT user_id, SUM(daily_profit) as total_profit
  FROM nft_daily_profit
  WHERE user_id IN ('59C23C', '177B83')
  GROUP BY user_id
),
withdrawal_sum AS (
  SELECT user_id, SUM(total_amount) as total_withdrawn
  FROM monthly_withdrawals
  WHERE user_id IN ('59C23C', '177B83')
    AND status = 'completed'
  GROUP BY user_id
),
correct_values AS (
  SELECT 
    ac.user_id,
    ROUND((ps.total_profit + ac.withdrawn_referral_usdt + (ac.auto_nft_count * 1100) - COALESCE(ws.total_withdrawn, 0))::numeric, 2) as correct_available
  FROM affiliate_cycle ac
  LEFT JOIN profit_sum ps ON ac.user_id = ps.user_id
  LEFT JOIN withdrawal_sum ws ON ac.user_id = ws.user_id
  WHERE ac.user_id IN ('59C23C', '177B83')
)
UPDATE affiliate_cycle ac
SET 
  available_usdt = cv.correct_available,
  updated_at = NOW()
FROM correct_values cv
WHERE ac.user_id = cv.user_id;

-- STEP 4: 修正後の確認
SELECT '=== STEP 4: 修正後 ===' as section;
SELECT 
  user_id,
  available_usdt,
  cum_usdt,
  phase
FROM affiliate_cycle
WHERE user_id IN ('59C23C', '177B83');
