-- ========================================
-- 1月pending出金のreferral_amount修正
-- ========================================

-- 1. 現状確認：monthly_referral_profitに1月データがあるのにreferral=0
SELECT '=== 1. 修正対象ユーザー ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  ROUND(mrp.jan_referral::numeric, 2) as "1月紹介報酬",
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt",
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as "withdrawn_referral",
  ROUND(COALESCE(mw.referral_amount, 0)::numeric, 2) as "現在のreferral_amount",
  ROUND(mw.personal_amount::numeric, 2) as "personal_amount",
  ROUND(mw.total_amount::numeric, 2) as "現在のtotal_amount"
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
JOIN (
  SELECT user_id, SUM(profit_amount) as jan_referral
  FROM monthly_referral_profit
  WHERE year_month = '2026-01'
  GROUP BY user_id
) mrp ON mw.user_id = mrp.user_id
WHERE mw.withdrawal_month = '2026-01-01'
  AND mw.status IN ('pending', 'on_hold')
  AND COALESCE(mw.referral_amount, 0) = 0
ORDER BY mrp.jan_referral DESC;

-- 2. 出金可能な紹介報酬の計算
-- USDTフェーズ: cum_usdt - withdrawn_referral_usdt（全額出金可能）
-- HOLDフェーズ: cum_usdt - 1100 - withdrawn_referral_usdt（$1100をロック）
SELECT '=== 2. 出金可能紹介報酬の計算 ===' as section;
SELECT
  mw.user_id,
  ac.phase,
  ROUND(mrp.jan_referral::numeric, 2) as "1月紹介報酬",
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt",
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as "withdrawn_referral",
  CASE
    WHEN ac.phase = 'USDT' THEN
      ROUND(GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
    WHEN ac.phase = 'HOLD' THEN
      ROUND(GREATEST(0, ac.cum_usdt - 1100 - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2)
  END as "出金可能紹介報酬"
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
JOIN (
  SELECT user_id, SUM(profit_amount) as jan_referral
  FROM monthly_referral_profit
  WHERE year_month = '2026-01'
  GROUP BY user_id
) mrp ON mw.user_id = mrp.user_id
WHERE mw.withdrawal_month = '2026-01-01'
  AND mw.status IN ('pending', 'on_hold')
  AND COALESCE(mw.referral_amount, 0) = 0
ORDER BY mrp.jan_referral DESC;

-- 3. referral_amountとtotal_amountを更新
-- ※まず確認してから実行すること
/*
UPDATE monthly_withdrawals mw
SET
  referral_amount = calc.withdrawable_referral,
  total_amount = mw.personal_amount + calc.withdrawable_referral
FROM (
  SELECT
    mw2.id,
    CASE
      WHEN ac.phase = 'USDT' THEN
        GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))
      WHEN ac.phase = 'HOLD' THEN
        GREATEST(0, ac.cum_usdt - 1100 - COALESCE(ac.withdrawn_referral_usdt, 0))
    END as withdrawable_referral
  FROM monthly_withdrawals mw2
  JOIN affiliate_cycle ac ON mw2.user_id = ac.user_id
  WHERE mw2.withdrawal_month = '2026-01-01'
    AND mw2.status IN ('pending', 'on_hold')
    AND EXISTS (
      SELECT 1 FROM monthly_referral_profit mrp
      WHERE mrp.user_id = mw2.user_id
      AND mrp.year_month = '2026-01'
    )
    AND COALESCE(mw2.referral_amount, 0) = 0
) calc
WHERE mw.id = calc.id
  AND calc.withdrawable_referral > 0;
*/

-- 4. 380CE2の詳細確認
SELECT '=== 4. 380CE2の詳細 ===' as section;
SELECT
  ac.user_id,
  ac.phase,
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt",
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as "withdrawn_referral",
  ROUND((ac.cum_usdt - 1100)::numeric, 2) as "cum_usdt - 1100",
  ROUND((ac.cum_usdt - 1100 - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2) as "出金可能（理論値）"
FROM affiliate_cycle ac
WHERE ac.user_id = '380CE2';

-- 5. 380CE2の月別紹介報酬
SELECT '=== 5. 380CE2の月別紹介報酬 ===' as section;
SELECT
  year_month,
  referral_level,
  COUNT(*) as records,
  ROUND(SUM(profit_amount)::numeric, 2) as total
FROM monthly_referral_profit
WHERE user_id = '380CE2'
GROUP BY year_month, referral_level
ORDER BY year_month, referral_level;

-- 6. 59C23Cと177B83の詳細確認
SELECT '=== 6. 59C23C, 177B83の詳細 ===' as section;
SELECT
  ac.user_id,
  ac.phase,
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt",
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as "withdrawn_referral",
  ac.auto_nft_count,
  ROUND((ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2) as "出金可能（理論値）"
FROM affiliate_cycle ac
WHERE ac.user_id IN ('59C23C', '177B83');

-- 7. 59C23Cと177B83の月別紹介報酬（全累計確認）
SELECT '=== 7. 59C23C, 177B83の月別紹介報酬 ===' as section;
SELECT
  user_id,
  year_month,
  ROUND(SUM(profit_amount)::numeric, 2) as monthly_total
FROM monthly_referral_profit
WHERE user_id IN ('59C23C', '177B83')
GROUP BY user_id, year_month
ORDER BY user_id, year_month;

-- 8. 全累計との比較
SELECT '=== 8. 紹介報酬累計 vs cum_usdt ===' as section;
SELECT
  mrp.user_id,
  ROUND(mrp.total_referral::numeric, 2) as "紹介報酬累計",
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt",
  ac.auto_nft_count,
  ROUND((ac.auto_nft_count * 2200)::numeric, 2) as "NFT自動購入分",
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as "withdrawn_referral",
  ROUND((mrp.total_referral - ac.cum_usdt - (ac.auto_nft_count * 2200))::numeric, 2) as "差分"
FROM (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  WHERE user_id IN ('59C23C', '177B83', '380CE2', '5FAE2C')
  GROUP BY user_id
) mrp
JOIN affiliate_cycle ac ON mrp.user_id = ac.user_id
ORDER BY mrp.total_referral DESC;
