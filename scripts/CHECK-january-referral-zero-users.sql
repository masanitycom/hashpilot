-- ========================================
-- 1月紹介報酬が0のユーザー全調査
-- ========================================

-- 1. 1月pending/on_hold出金でreferral_amount=0のユーザー一覧
SELECT '=== 1. 1月紹介報酬=0のユーザー一覧 ===' as section;
SELECT
  mw.user_id,
  ROUND(mw.personal_amount::numeric, 2) as personal,
  ROUND(COALESCE(mw.referral_amount, 0)::numeric, 2) as referral,
  mw.status,
  ac.phase,
  ROUND(ac.cum_usdt::numeric, 2) as cum_usdt
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2026-01-01'
  AND mw.status IN ('pending', 'on_hold')
  AND COALESCE(mw.referral_amount, 0) = 0
ORDER BY mw.personal_amount DESC;

-- 2. 上記ユーザーが紹介者を持っているか確認
SELECT '=== 2. referral=0ユーザーの紹介者数 ===' as section;
SELECT
  mw.user_id,
  COUNT(DISTINCT child.user_id) as "直接紹介者数(L1)",
  COUNT(DISTINCT grandchild.user_id) as "間接紹介者数(L2)"
FROM monthly_withdrawals mw
LEFT JOIN users child ON child.referrer_user_id = mw.user_id
LEFT JOIN users grandchild ON grandchild.referrer_user_id = child.user_id
WHERE mw.withdrawal_month = '2026-01-01'
  AND mw.status IN ('pending', 'on_hold')
  AND COALESCE(mw.referral_amount, 0) = 0
GROUP BY mw.user_id
HAVING COUNT(DISTINCT child.user_id) > 0
ORDER BY COUNT(DISTINCT child.user_id) DESC;

-- 3. 紹介者がいるのにreferral=0のユーザーの詳細
SELECT '=== 3. 紹介者ありでreferral=0の詳細 ===' as section;
SELECT
  mw.user_id,
  child.user_id as "紹介したユーザー",
  child.has_approved_nft as "NFT承認済",
  child.operation_start_date as "運用開始日",
  ROUND(COALESCE(jan_profit.total, 0)::numeric, 2) as "1月日利"
FROM monthly_withdrawals mw
JOIN users child ON child.referrer_user_id = mw.user_id
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total
  FROM nft_daily_profit
  WHERE date >= '2026-01-01' AND date < '2026-02-01'
  GROUP BY user_id
) jan_profit ON child.user_id = jan_profit.user_id
WHERE mw.withdrawal_month = '2026-01-01'
  AND mw.status IN ('pending', 'on_hold')
  AND COALESCE(mw.referral_amount, 0) = 0
  AND child.has_approved_nft = true
ORDER BY mw.user_id, jan_profit.total DESC NULLS LAST;

-- 4. 紹介者がいて、紹介者に1月日利があるのにreferral=0のユーザー
SELECT '=== 4. 問題あり：紹介者の1月日利あり＆自分のreferral=0 ===' as section;
SELECT
  mw.user_id,
  COUNT(DISTINCT child.user_id) as "紹介者数",
  ROUND(SUM(COALESCE(jan_profit.total, 0))::numeric, 2) as "紹介者の1月日利合計",
  ROUND(SUM(COALESCE(jan_profit.total, 0)) * 0.20::numeric, 2) as "本来のL1報酬(20%)"
FROM monthly_withdrawals mw
JOIN users child ON child.referrer_user_id = mw.user_id
  AND child.has_approved_nft = true
  AND child.operation_start_date <= '2026-01-31'
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total
  FROM nft_daily_profit
  WHERE date >= '2026-01-01' AND date < '2026-02-01'
  GROUP BY user_id
) jan_profit ON child.user_id = jan_profit.user_id
WHERE mw.withdrawal_month = '2026-01-01'
  AND mw.status IN ('pending', 'on_hold')
  AND COALESCE(mw.referral_amount, 0) = 0
GROUP BY mw.user_id
HAVING SUM(COALESCE(jan_profit.total, 0)) > 0
ORDER BY SUM(COALESCE(jan_profit.total, 0)) DESC;

-- 5. monthly_referral_profitに1月データがあるのにpending referral=0のユーザー
SELECT '=== 5. monthly_referral_profitに1月データあり＆pending=0 ===' as section;
SELECT
  mw.user_id,
  ROUND(mrp.jan_total::numeric, 2) as "1月紹介報酬(計算済)",
  ROUND(COALESCE(mw.referral_amount, 0)::numeric, 2) as "pending referral",
  ac.phase,
  ROUND(ac.cum_usdt::numeric, 2) as cum_usdt,
  ROUND(COALESCE(ac.withdrawn_referral_usdt, 0)::numeric, 2) as withdrawn_referral
FROM monthly_withdrawals mw
JOIN (
  SELECT user_id, SUM(profit_amount) as jan_total
  FROM monthly_referral_profit
  WHERE year_month = '2026-01'
  GROUP BY user_id
) mrp ON mw.user_id = mrp.user_id
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2026-01-01'
  AND mw.status IN ('pending', 'on_hold')
  AND COALESCE(mw.referral_amount, 0) = 0
ORDER BY mrp.jan_total DESC;

-- 6. 統計サマリー
SELECT '=== 6. 統計サマリー ===' as section;
SELECT
  (SELECT COUNT(*) FROM monthly_withdrawals WHERE withdrawal_month = '2026-01-01' AND status IN ('pending', 'on_hold')) as "1月pending/on_hold総数",
  (SELECT COUNT(*) FROM monthly_withdrawals WHERE withdrawal_month = '2026-01-01' AND status IN ('pending', 'on_hold') AND COALESCE(referral_amount, 0) = 0) as "referral=0",
  (SELECT COUNT(*) FROM monthly_withdrawals WHERE withdrawal_month = '2026-01-01' AND status IN ('pending', 'on_hold') AND COALESCE(referral_amount, 0) > 0) as "referral>0";
