-- ========================================
-- 複数月の未払い出金があるユーザー全員
-- ========================================

-- 1. 複数月の未払いがあるユーザー
SELECT '=== 1. 複数月の未払いユーザー ===' as section;
SELECT
  user_id,
  COUNT(*) as pending_count,
  ROUND(SUM(personal_amount)::numeric, 2) as total_personal,
  ROUND(SUM(total_amount)::numeric, 2) as total_amount,
  array_agg(withdrawal_month ORDER BY withdrawal_month) as months
FROM monthly_withdrawals
WHERE status IN ('pending', 'on_hold')
GROUP BY user_id
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC, total_amount DESC;

-- 2. 単月の未払いも含めた全体像
SELECT '=== 2. 未払い出金の月別分布 ===' as section;
SELECT
  withdrawal_month,
  status,
  COUNT(*) as user_count,
  ROUND(SUM(personal_amount)::numeric, 2) as total_personal,
  ROUND(SUM(total_amount)::numeric, 2) as total_amount
FROM monthly_withdrawals
WHERE status IN ('pending', 'on_hold')
GROUP BY withdrawal_month, status
ORDER BY withdrawal_month, status;

-- 3. available_usdtとの不一致（全員）
SELECT '=== 3. available_usdtとの不一致 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as available_usdt,
  ROUND(pending.total_personal::numeric, 2) as "未払い合計",
  ROUND((pending.total_personal - ac.available_usdt)::numeric, 2) as "差分",
  pending.pending_count as "未払い月数"
FROM affiliate_cycle ac
JOIN (
  SELECT
    user_id,
    COUNT(*) as pending_count,
    SUM(personal_amount) as total_personal
  FROM monthly_withdrawals
  WHERE status IN ('pending', 'on_hold')
  GROUP BY user_id
) pending ON ac.user_id = pending.user_id
WHERE ABS(pending.total_personal - ac.available_usdt) >= 0.01
ORDER BY ABS(pending.total_personal - ac.available_usdt) DESC;

-- 4. 統計
SELECT '=== 4. 統計 ===' as section;
SELECT
  COUNT(DISTINCT user_id) as "未払いユーザー数",
  SUM(CASE WHEN pending_count > 1 THEN 1 ELSE 0 END) as "複数月未払い",
  ROUND(SUM(total_personal)::numeric, 2) as "未払い合計"
FROM (
  SELECT
    user_id,
    COUNT(*) as pending_count,
    SUM(personal_amount) as total_personal
  FROM monthly_withdrawals
  WHERE status IN ('pending', 'on_hold')
  GROUP BY user_id
) sub;
