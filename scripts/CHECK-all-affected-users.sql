-- ========================================
-- 全ユーザーの影響確認
-- ========================================

-- 1. マイナスになっているユーザー一覧
SELECT '=== 1. マイナスavailable_usdtユーザー ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as available_usdt,
  ROUND(ac.cum_usdt::numeric, 2) as cum_usdt,
  ac.phase
FROM affiliate_cycle ac
WHERE ac.available_usdt < 0
ORDER BY ac.available_usdt ASC
LIMIT 30;

-- 2. pending出金との比較（ズレがあるユーザー）
SELECT '=== 2. pending出金とavailable_usdtの差分 ===' as section;
SELECT
  mw.user_id,
  ROUND(mw.personal_amount::numeric, 2) as "pending個人利益",
  ROUND(ac.available_usdt::numeric, 2) as "available_usdt",
  ROUND((mw.personal_amount - ac.available_usdt)::numeric, 2) as "差分",
  CASE
    WHEN ABS(mw.personal_amount - ac.available_usdt) > 1 THEN '⚠ ズレあり'
    ELSE '✓'
  END as status
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.status = 'pending'
  AND mw.personal_amount IS NOT NULL
ORDER BY ABS(mw.personal_amount - ac.available_usdt) DESC
LIMIT 30;

-- 3. 大きなズレがあるユーザー数
SELECT '=== 3. ズレの統計 ===' as section;
SELECT
  COUNT(*) as "pending出金ユーザー数",
  COUNT(*) FILTER (WHERE ABS(mw.personal_amount - ac.available_usdt) > 1) as "ズレ>$1",
  COUNT(*) FILTER (WHERE ABS(mw.personal_amount - ac.available_usdt) > 10) as "ズレ>$10",
  COUNT(*) FILTER (WHERE ABS(mw.personal_amount - ac.available_usdt) > 100) as "ズレ>$100"
FROM monthly_withdrawals mw
JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.status = 'pending'
  AND mw.personal_amount IS NOT NULL;

-- 4. 全体の状態
SELECT '=== 4. affiliate_cycle全体統計 ===' as section;
SELECT
  COUNT(*) as "全ユーザー",
  COUNT(*) FILTER (WHERE available_usdt < -100) as "< -$100",
  COUNT(*) FILTER (WHERE available_usdt >= -100 AND available_usdt < 0) as "-$100〜$0",
  COUNT(*) FILTER (WHERE available_usdt >= 0 AND available_usdt < 10) as "$0〜$10",
  COUNT(*) FILTER (WHERE available_usdt >= 10 AND available_usdt < 100) as "$10〜$100",
  COUNT(*) FILTER (WHERE available_usdt >= 100) as ">= $100"
FROM affiliate_cycle;

-- 5. pending出金のpersonal_amountがNULLのユーザー
SELECT '=== 5. personal_amountがNULLのpending出金 ===' as section;
SELECT
  user_id,
  withdrawal_month,
  ROUND(total_amount::numeric, 2) as total_amount,
  personal_amount,
  referral_amount
FROM monthly_withdrawals
WHERE status = 'pending'
  AND personal_amount IS NULL
LIMIT 20;
