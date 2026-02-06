-- ========================================
-- まだマイナスのユーザー調査
-- ========================================

-- 1. マイナスユーザーの内訳
SELECT '=== 1. マイナスユーザーの分類 ===' as section;
SELECT
  CASE
    WHEN EXISTS (SELECT 1 FROM monthly_withdrawals mw WHERE mw.user_id = ac.user_id AND mw.status = 'pending') THEN 'pending出金あり'
    WHEN EXISTS (SELECT 1 FROM monthly_withdrawals mw WHERE mw.user_id = ac.user_id AND mw.status = 'completed') THEN 'completed出金のみ'
    WHEN EXISTS (SELECT 1 FROM nft_daily_profit ndp WHERE ndp.user_id = ac.user_id) THEN '日利のみ（出金なし）'
    ELSE 'データなし'
  END as category,
  COUNT(*) as count,
  ROUND(SUM(available_usdt)::numeric, 2) as total_available
FROM affiliate_cycle ac
WHERE ac.available_usdt < 0
GROUP BY 1
ORDER BY count DESC;

-- 2. pending出金あり＆マイナスの5名
SELECT '=== 2. pending出金あり＆マイナスの5名 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as available_usdt,
  ROUND(mw.personal_amount::numeric, 2) as pending_personal,
  mw.status
FROM affiliate_cycle ac
JOIN monthly_withdrawals mw ON ac.user_id = mw.user_id AND mw.status = 'pending'
WHERE ac.available_usdt < 0;

-- 3. completed出金のみでマイナスのユーザー（上位20名）
SELECT '=== 3. completed出金のみでマイナス ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as available_usdt,
  ROUND(COALESCE(dp.total, 0)::numeric, 2) as "日利合計",
  ROUND(COALESCE(w.personal_sum, 0)::numeric, 2) as "出金済み個人",
  w.withdrawal_count as "出金回数"
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(daily_profit) as total
  FROM nft_daily_profit GROUP BY user_id
) dp ON ac.user_id = dp.user_id
LEFT JOIN (
  SELECT
    user_id,
    COUNT(*) as withdrawal_count,
    SUM(
      CASE
        WHEN personal_amount IS NOT NULL THEN personal_amount
        ELSE GREATEST(0, total_amount - COALESCE(referral_amount, 0))
      END
    ) as personal_sum
  FROM monthly_withdrawals
  WHERE status = 'completed'
  GROUP BY user_id
) w ON ac.user_id = w.user_id
WHERE ac.available_usdt < 0
  AND NOT EXISTS (SELECT 1 FROM monthly_withdrawals mw WHERE mw.user_id = ac.user_id AND mw.status = 'pending')
  AND EXISTS (SELECT 1 FROM monthly_withdrawals mw WHERE mw.user_id = ac.user_id AND mw.status = 'completed')
ORDER BY ac.available_usdt ASC
LIMIT 20;

-- 4. 出金履歴の詳細（最もマイナスが大きいユーザー）
SELECT '=== 4. 9DDF45の出金履歴詳細 ===' as section;
SELECT
  withdrawal_month,
  status,
  ROUND(COALESCE(personal_amount, 0)::numeric, 2) as personal,
  ROUND(COALESCE(referral_amount, 0)::numeric, 2) as referral,
  ROUND(total_amount::numeric, 2) as total,
  CASE WHEN personal_amount IS NULL THEN 'NULL' ELSE 'SET' END as personal_status
FROM monthly_withdrawals
WHERE user_id = '9DDF45'
ORDER BY withdrawal_month;

-- 5. 9DDF45の日利詳細
SELECT '=== 5. 9DDF45の月別日利 ===' as section;
SELECT
  TO_CHAR(date, 'YYYY-MM') as month,
  ROUND(SUM(daily_profit)::numeric, 2) as daily_profit
FROM nft_daily_profit
WHERE user_id = '9DDF45'
GROUP BY TO_CHAR(date, 'YYYY-MM')
ORDER BY month;

-- 6. pending出金がないユーザーで日利があるケース
SELECT '=== 6. pending出金なし＆日利ありの確認 ===' as section;
SELECT
  ac.user_id,
  ROUND(ac.available_usdt::numeric, 2) as available_usdt,
  ROUND(dp.total::numeric, 2) as "日利合計",
  EXISTS (SELECT 1 FROM monthly_withdrawals mw WHERE mw.user_id = ac.user_id AND mw.status = 'completed') as "completed出金あり"
FROM affiliate_cycle ac
JOIN (
  SELECT user_id, SUM(daily_profit) as total
  FROM nft_daily_profit GROUP BY user_id
) dp ON ac.user_id = dp.user_id
WHERE ac.available_usdt < 0
  AND NOT EXISTS (SELECT 1 FROM monthly_withdrawals mw WHERE mw.user_id = ac.user_id AND mw.status = 'pending')
ORDER BY ac.available_usdt ASC
LIMIT 20;
