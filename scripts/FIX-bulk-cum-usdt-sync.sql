-- ========================================
-- cum_usdt一括同期スクリプト
-- ========================================
-- 目的: 全ユーザーのcum_usdtをmonthly_referral_profitの合計と一致させる
-- 同時にphaseも再計算

-- STEP 1: 修正前の不整合件数を確認
SELECT '=== STEP 1: 修正前の不整合件数 ===' as section;
WITH correct_cum AS (
  SELECT 
    user_id,
    ROUND(SUM(profit_amount)::numeric, 2) as correct_cum_usdt
  FROM monthly_referral_profit
  GROUP BY user_id
)
SELECT COUNT(*) as 不整合件数
FROM affiliate_cycle ac
LEFT JOIN correct_cum cc ON ac.user_id = cc.user_id
WHERE ABS(COALESCE(cc.correct_cum_usdt, 0) - ac.cum_usdt) > 0.01;

-- STEP 2: 一括修正を実行
SELECT '=== STEP 2: cum_usdtとphaseを一括修正 ===' as section;

WITH correct_cum AS (
  SELECT 
    user_id,
    ROUND(SUM(profit_amount)::numeric, 2) as correct_cum_usdt
  FROM monthly_referral_profit
  GROUP BY user_id
)
UPDATE affiliate_cycle ac
SET 
  cum_usdt = COALESCE(cc.correct_cum_usdt, 0),
  phase = CASE 
    WHEN (FLOOR(COALESCE(cc.correct_cum_usdt, 0) / 1100)::int % 2) = 0 THEN 'USDT'
    ELSE 'HOLD'
  END,
  updated_at = NOW()
FROM correct_cum cc
WHERE ac.user_id = cc.user_id
  AND (ABS(COALESCE(cc.correct_cum_usdt, 0) - ac.cum_usdt) > 0.01
       OR ac.phase != CASE 
            WHEN (FLOOR(COALESCE(cc.correct_cum_usdt, 0) / 1100)::int % 2) = 0 THEN 'USDT'
            ELSE 'HOLD'
          END);

-- STEP 3: 紹介報酬がないユーザーのcum_usdtを0にリセット
SELECT '=== STEP 3: 紹介報酬なしユーザーをリセット ===' as section;

UPDATE affiliate_cycle ac
SET 
  cum_usdt = 0,
  phase = 'USDT',
  updated_at = NOW()
WHERE NOT EXISTS (
  SELECT 1 FROM monthly_referral_profit mrp WHERE mrp.user_id = ac.user_id
)
AND ac.cum_usdt != 0;

-- STEP 4: 修正後の確認
SELECT '=== STEP 4: 修正後の不整合件数 ===' as section;
WITH correct_cum AS (
  SELECT 
    user_id,
    ROUND(SUM(profit_amount)::numeric, 2) as correct_cum_usdt
  FROM monthly_referral_profit
  GROUP BY user_id
)
SELECT COUNT(*) as 残り不整合件数
FROM affiliate_cycle ac
LEFT JOIN correct_cum cc ON ac.user_id = cc.user_id
WHERE ABS(COALESCE(cc.correct_cum_usdt, 0) - ac.cum_usdt) > 0.01;

-- STEP 5: フェーズ別集計
SELECT '=== STEP 5: フェーズ別集計 ===' as section;
SELECT 
  phase,
  COUNT(*) as ユーザー数,
  ROUND(SUM(cum_usdt)::numeric, 2) as cum_usdt合計
FROM affiliate_cycle
GROUP BY phase
ORDER BY phase;
