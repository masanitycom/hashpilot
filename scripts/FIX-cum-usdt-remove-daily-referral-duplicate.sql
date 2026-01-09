-- ========================================
-- cum_usdtとavailable_usdtから日次紹介報酬の二重加算を修正
-- ========================================
-- 実行日: 2026-01-09
-- 問題: 日次紹介報酬（user_referral_profit）が廃止されたが、
--       cum_usdtとavailable_usdtに二重加算されたまま残っている
-- 修正: cum_usdtをmonthly_referral_profitの合計に修正
--       available_usdtから二重加算分を減算
-- ========================================

-- ========================================
-- STEP 1: 修正前の状態確認
-- ========================================
SELECT '=== STEP 1: 修正前の状態 ===' as section;

SELECT
  COUNT(*) as affected_users,
  SUM(ac.cum_usdt - COALESCE(mrp.monthly_total, 0)) as total_difference,
  SUM(COALESCE(urp.daily_total, 0)) as total_daily_referral
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as monthly_total
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as daily_total
  FROM user_referral_profit
  GROUP BY user_id
) urp ON ac.user_id = urp.user_id
WHERE ABS(ac.cum_usdt - COALESCE(mrp.monthly_total, 0)) > 0.01;

-- ========================================
-- STEP 2: cum_usdtをmonthly_referral_profitの合計に修正
-- ========================================
UPDATE affiliate_cycle ac
SET
  cum_usdt = COALESCE(mrp.monthly_total, 0),
  updated_at = NOW()
FROM (
  SELECT user_id, SUM(profit_amount) as monthly_total
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp
WHERE ac.user_id = mrp.user_id;

-- cum_usdtがNULLまたは紹介報酬がないユーザーは0に設定
UPDATE affiliate_cycle
SET cum_usdt = 0, updated_at = NOW()
WHERE user_id NOT IN (SELECT DISTINCT user_id FROM monthly_referral_profit);

-- ========================================
-- STEP 3: available_usdtから日次紹介報酬の二重加算分を減算
-- ========================================
UPDATE affiliate_cycle ac
SET
  available_usdt = GREATEST(0, ac.available_usdt - COALESCE(urp.daily_total, 0)),
  updated_at = NOW()
FROM (
  SELECT user_id, SUM(profit_amount) as daily_total
  FROM user_referral_profit
  GROUP BY user_id
) urp
WHERE ac.user_id = urp.user_id
  AND urp.daily_total > 0;

-- ========================================
-- STEP 4: phaseを再計算
-- ========================================
UPDATE affiliate_cycle
SET
  phase = CASE
    WHEN cum_usdt < 1100 THEN 'USDT'
    WHEN (FLOOR(cum_usdt / 1100)::int % 2) = 0 THEN 'USDT'
    ELSE 'HOLD'
  END,
  updated_at = NOW();

-- ========================================
-- STEP 5: 修正後の確認
-- ========================================
SELECT '=== STEP 5: 修正後の状態 ===' as section;

SELECT
  COUNT(*) as total_users,
  SUM(CASE WHEN ABS(ac.cum_usdt - COALESCE(mrp.monthly_total, 0)) > 0.01 THEN 1 ELSE 0 END) as still_mismatched
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as monthly_total
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id;

-- ========================================
-- STEP 6: 5FAE2Cの確認
-- ========================================
SELECT '=== STEP 6: 5FAE2C確認 ===' as section;

SELECT
  ac.user_id,
  ac.cum_usdt,
  ac.available_usdt,
  ac.phase,
  COALESCE(mrp.monthly_total, 0) as monthly_referral
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as monthly_total
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
WHERE ac.user_id = '5FAE2C';

-- ========================================
-- 完了メッセージ
-- ========================================
DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'cum_usdtとavailable_usdtの二重加算を修正完了';
  RAISE NOTICE '========================================';
END $$;
