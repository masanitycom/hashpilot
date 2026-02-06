-- ========================================
-- 1月pending出金がないユーザー確認
-- ========================================

-- 1. B51CA4, 1A1610, 5AB27Dの全出金履歴
SELECT '=== 1. 3名の出金履歴 ===' as section;
SELECT
  user_id,
  withdrawal_month,
  status,
  ROUND(personal_amount::numeric, 2) as personal,
  ROUND(COALESCE(referral_amount, 0)::numeric, 2) as referral,
  ROUND(total_amount::numeric, 2) as total
FROM monthly_withdrawals
WHERE user_id IN ('B51CA4', '1A1610', '5AB27D')
ORDER BY user_id, withdrawal_month;

-- 2. これらのユーザーの運用状態
SELECT '=== 2. 運用状態 ===' as section;
SELECT
  u.user_id,
  u.operation_start_date,
  u.has_approved_nft,
  (SELECT COUNT(*) FROM nft_master nm WHERE nm.user_id = u.user_id AND nm.buyback_date IS NULL) as nft_count
FROM users u
WHERE u.user_id IN ('B51CA4', '1A1610', '5AB27D');

-- 3. 日利データがあるか
SELECT '=== 3. 日利データ ===' as section;
SELECT
  user_id,
  TO_CHAR(MIN(date), 'YYYY-MM-DD') as first_date,
  TO_CHAR(MAX(date), 'YYYY-MM-DD') as last_date,
  COUNT(*) as days,
  ROUND(SUM(daily_profit)::numeric, 2) as total_profit
FROM nft_daily_profit
WHERE user_id IN ('B51CA4', '1A1610', '5AB27D')
GROUP BY user_id;

-- 4. 全体で1月pending出金がないユーザー数
SELECT '=== 4. 1月pending出金がない活動ユーザー ===' as section;
SELECT
  COUNT(*) as "1月pending出金なし"
FROM users u
WHERE u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= '2026-01-31'
  AND NOT EXISTS (
    SELECT 1 FROM monthly_withdrawals mw
    WHERE mw.user_id = u.user_id
    AND mw.withdrawal_month = '2026-01-01'
  );
