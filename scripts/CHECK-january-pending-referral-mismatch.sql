-- ========================================
-- 1月pending出金のreferral_amount確認
-- ========================================

-- 1. 1月の紹介報酬があるがpending出金でreferral=0のユーザー
SELECT '=== 1. 紹介報酬ありだがpending referral=0 ===' as section;
SELECT
  mrp.user_id,
  ROUND(mrp.jan_referral::numeric, 2) as "1月紹介報酬",
  ROUND(COALESCE(mw.referral_amount, 0)::numeric, 2) as "pending referral",
  ac.phase,
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt",
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as "withdrawn_referral"
FROM (
  SELECT user_id, SUM(profit_amount) as jan_referral
  FROM monthly_referral_profit
  WHERE year_month = '2026-01'
  GROUP BY user_id
) mrp
LEFT JOIN monthly_withdrawals mw ON mrp.user_id = mw.user_id
  AND mw.withdrawal_month = '2026-01-01'
  AND mw.status IN ('pending', 'on_hold')
LEFT JOIN affiliate_cycle ac ON mrp.user_id = ac.user_id
WHERE COALESCE(mw.referral_amount, 0) = 0
  AND ac.phase = 'USDT'
ORDER BY mrp.jan_referral DESC
LIMIT 30;

-- 2. 統計
SELECT '=== 2. 統計 ===' as section;
SELECT
  COUNT(*) as "1月紹介報酬ありユーザー",
  COUNT(*) FILTER (WHERE COALESCE(mw.referral_amount, 0) = 0) as "pending referral=0",
  COUNT(*) FILTER (WHERE COALESCE(mw.referral_amount, 0) > 0) as "pending referral>0",
  COUNT(*) FILTER (WHERE ac.phase = 'HOLD') as "HOLDフェーズ",
  COUNT(*) FILTER (WHERE mw.user_id IS NULL) as "pending出金なし"
FROM (
  SELECT user_id, SUM(profit_amount) as jan_referral
  FROM monthly_referral_profit
  WHERE year_month = '2026-01'
  GROUP BY user_id
) mrp
LEFT JOIN monthly_withdrawals mw ON mrp.user_id = mw.user_id
  AND mw.withdrawal_month = '2026-01-01'
  AND mw.status IN ('pending', 'on_hold')
LEFT JOIN affiliate_cycle ac ON mrp.user_id = ac.user_id;

-- 3. USDTフェーズで紹介報酬があるのにpending referral=0の人数
SELECT '=== 3. 修正が必要なユーザー数 ===' as section;
SELECT
  COUNT(*) as "修正必要数",
  ROUND(SUM(
    GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))
  )::numeric, 2) as "出金可能紹介報酬合計"
FROM (
  SELECT user_id, SUM(profit_amount) as jan_referral
  FROM monthly_referral_profit
  WHERE year_month = '2026-01'
  GROUP BY user_id
) mrp
JOIN monthly_withdrawals mw ON mrp.user_id = mw.user_id
  AND mw.withdrawal_month = '2026-01-01'
  AND mw.status IN ('pending', 'on_hold')
JOIN affiliate_cycle ac ON mrp.user_id = ac.user_id
WHERE COALESCE(mw.referral_amount, 0) = 0
  AND ac.phase = 'USDT'
  AND ac.cum_usdt > COALESCE(ac.withdrawn_referral_usdt, 0);

-- 4. 具体例
SELECT '=== 4. 修正が必要なユーザー例 ===' as section;
SELECT
  mw.user_id,
  ROUND(mrp.jan_referral::numeric, 2) as "1月紹介報酬",
  ROUND(ac.cum_usdt::numeric, 2) as "cum_usdt",
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as "withdrawn",
  ROUND(GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))::numeric, 2) as "出金可能",
  ROUND(COALESCE(mw.referral_amount, 0)::numeric, 2) as "現在のpending referral"
FROM (
  SELECT user_id, SUM(profit_amount) as jan_referral
  FROM monthly_referral_profit
  WHERE year_month = '2026-01'
  GROUP BY user_id
) mrp
JOIN monthly_withdrawals mw ON mrp.user_id = mw.user_id
  AND mw.withdrawal_month = '2026-01-01'
  AND mw.status IN ('pending', 'on_hold')
JOIN affiliate_cycle ac ON mrp.user_id = ac.user_id
WHERE COALESCE(mw.referral_amount, 0) = 0
  AND ac.phase = 'USDT'
  AND ac.cum_usdt > COALESCE(ac.withdrawn_referral_usdt, 0)
ORDER BY GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0)) DESC
LIMIT 20;
