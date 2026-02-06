-- ========================================
-- 全未払いユーザーのavailable_usdt修正
-- ========================================
-- ロジック:
--   pending/on_hold出金があるユーザー → SUM(全ての未払いpersonal_amount)
--   pending/on_hold出金がないユーザー → 日利合計（変更なし）
-- ========================================

-- STEP 0: 修正前の状態
SELECT '=== STEP 0: 修正前の統計 ===' as section;
SELECT
  COUNT(*) as "不一致ユーザー数"
FROM affiliate_cycle ac
JOIN (
  SELECT user_id, SUM(personal_amount) as total_personal
  FROM monthly_withdrawals
  WHERE status IN ('pending', 'on_hold')
  GROUP BY user_id
) pending ON ac.user_id = pending.user_id
WHERE ABS(pending.total_personal - ac.available_usdt) >= 0.01;

-- STEP 1: 全ての未払いユーザーのavailable_usdtを修正
SELECT '=== STEP 1: 未払いユーザーのavailable_usdt修正 ===' as section;

UPDATE affiliate_cycle ac
SET
  available_usdt = pending.total_personal,
  updated_at = NOW()
FROM (
  SELECT
    user_id,
    SUM(personal_amount) as total_personal
  FROM monthly_withdrawals
  WHERE status IN ('pending', 'on_hold')
  GROUP BY user_id
) pending
WHERE ac.user_id = pending.user_id;

-- STEP 2: 修正後の確認
SELECT '=== STEP 2: 修正後の統計 ===' as section;
SELECT
  COUNT(*) as "全ユーザー",
  COUNT(*) FILTER (WHERE available_usdt < 0) as "マイナス",
  COUNT(*) FILTER (WHERE available_usdt >= 0 AND available_usdt < 10) as "$0-10",
  COUNT(*) FILTER (WHERE available_usdt >= 10) as "$10以上",
  ROUND(SUM(available_usdt)::numeric, 2) as "合計"
FROM affiliate_cycle;

-- STEP 3: 不一致がなくなったか確認
SELECT '=== STEP 3: 不一致確認 ===' as section;
SELECT
  COUNT(*) as "未払いユーザー数",
  COUNT(*) FILTER (WHERE ABS(pending.total_personal - ac.available_usdt) < 0.01) as "一致",
  COUNT(*) FILTER (WHERE ABS(pending.total_personal - ac.available_usdt) >= 0.01) as "不一致"
FROM affiliate_cycle ac
JOIN (
  SELECT user_id, SUM(personal_amount) as total_personal
  FROM monthly_withdrawals
  WHERE status IN ('pending', 'on_hold')
  GROUP BY user_id
) pending ON ac.user_id = pending.user_id;

-- STEP 4: サンプル確認（複数月未払いユーザー）
SELECT '=== STEP 4: 複数月未払いユーザー確認 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as available_usdt,
  ROUND(pending.total_personal::numeric, 2) as "未払い合計",
  pending.pending_count as "月数"
FROM affiliate_cycle ac
JOIN (
  SELECT user_id, SUM(personal_amount) as total_personal, COUNT(*) as pending_count
  FROM monthly_withdrawals
  WHERE status IN ('pending', 'on_hold')
  GROUP BY user_id
  HAVING COUNT(*) > 1
) pending ON ac.user_id = pending.user_id
ORDER BY pending.pending_count DESC, pending.total_personal DESC;

SELECT '✅ 全未払いユーザーのavailable_usdt修正完了' as status;
