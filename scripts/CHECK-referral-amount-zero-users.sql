-- ========================================
-- referral_amount = 0 で紹介報酬があるはずのユーザーを調査
-- ========================================

-- ========================================
-- 1. monthly_referral_profitで11月分の紹介報酬があるが、
--    12月出金でreferral_amount = 0 のユーザー
-- ========================================
SELECT '=== 1. 11月紹介報酬があるのに12月出金でreferral=0のユーザー ===' as section;

SELECT
  mrp.user_id,
  SUM(mrp.profit_amount) as nov_referral_total,
  mw.referral_amount as dec_withdrawal_referral,
  mw.personal_amount as dec_withdrawal_personal,
  mw.total_amount as dec_withdrawal_total,
  ac.phase,
  ac.cum_usdt
FROM monthly_referral_profit mrp
LEFT JOIN monthly_withdrawals mw ON mrp.user_id = mw.user_id AND mw.withdrawal_month = '2025-12-01'
LEFT JOIN affiliate_cycle ac ON mrp.user_id = ac.user_id
WHERE mrp.year_month = '2025-11'
  AND (mw.referral_amount = 0 OR mw.referral_amount IS NULL)
  AND mw.id IS NOT NULL  -- 出金レコードが存在
GROUP BY mrp.user_id, mw.referral_amount, mw.personal_amount, mw.total_amount, ac.phase, ac.cum_usdt
ORDER BY SUM(mrp.profit_amount) DESC;

-- ========================================
-- 2. A81A5Eの詳細確認
-- ========================================
SELECT '=== 2. A81A5Eの詳細 ===' as section;

-- 2a. monthly_referral_profit（正しいテーブル）
SELECT '--- monthly_referral_profit ---' as table_name;
SELECT *
FROM monthly_referral_profit
WHERE user_id = 'A81A5E'
ORDER BY year_month;

-- 2b. user_referral_profit_monthly（存在確認）
SELECT '--- user_referral_profit_monthly（存在確認） ---' as table_name;
-- このテーブルが存在しない場合エラーになる
-- SELECT * FROM user_referral_profit_monthly WHERE user_id = 'A81A5E';

-- 2c. user_referral_profit（日次紹介報酬テーブル）
SELECT '--- user_referral_profit（日次） ---' as table_name;
SELECT user_id, date, profit_amount, referral_level
FROM user_referral_profit
WHERE user_id = 'A81A5E'
ORDER BY date;

-- ========================================
-- 3. テーブル存在確認
-- ========================================
SELECT '=== 3. テーブル存在確認 ===' as section;

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name LIKE '%referral%'
ORDER BY table_name;

-- ========================================
-- 4. 12月出金のreferral_amount統計
-- ========================================
SELECT '=== 4. 12月出金のreferral_amount統計 ===' as section;

SELECT
  CASE
    WHEN referral_amount IS NULL THEN 'NULL'
    WHEN referral_amount = 0 THEN '0'
    ELSE '> 0'
  END as referral_status,
  COUNT(*) as user_count,
  SUM(total_amount) as total_withdrawal
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01'
GROUP BY CASE
    WHEN referral_amount IS NULL THEN 'NULL'
    WHEN referral_amount = 0 THEN '0'
    ELSE '> 0'
  END;

-- ========================================
-- 5. referral_amount > 0 のユーザーはどこから値を取得したか確認
-- ========================================
SELECT '=== 5. referral_amount > 0 のユーザー分析 ===' as section;

SELECT
  mw.user_id,
  mw.referral_amount as withdrawal_referral,
  COALESCE(mrp_nov.nov_total, 0) as mrp_november,
  COALESCE(mrp_dec.dec_total, 0) as mrp_december,
  COALESCE(urp_dec.urp_december, 0) as urp_december,
  ac.phase,
  ac.cum_usdt
FROM monthly_withdrawals mw
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as nov_total
  FROM monthly_referral_profit
  WHERE year_month = '2025-11'
  GROUP BY user_id
) mrp_nov ON mw.user_id = mrp_nov.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as dec_total
  FROM monthly_referral_profit
  WHERE year_month = '2025-12'
  GROUP BY user_id
) mrp_dec ON mw.user_id = mrp_dec.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as urp_december
  FROM user_referral_profit
  WHERE date >= '2025-12-01' AND date < '2026-01-01'
  GROUP BY user_id
) urp_dec ON mw.user_id = urp_dec.user_id
LEFT JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND mw.referral_amount > 0
ORDER BY mw.referral_amount DESC
LIMIT 20;

-- ========================================
-- 6. 同様の問題を持つユーザー数（USDTフェーズで紹介報酬があるのに0）
-- ========================================
SELECT '=== 6. 問題のあるユーザー数 ===' as section;

SELECT
  COUNT(*) as affected_users,
  SUM(mrp.total_referral) as total_missing_referral
FROM (
  SELECT user_id, SUM(profit_amount) as total_referral
  FROM monthly_referral_profit
  WHERE year_month = '2025-11'
  GROUP BY user_id
) mrp
JOIN monthly_withdrawals mw ON mrp.user_id = mw.user_id AND mw.withdrawal_month = '2025-12-01'
JOIN affiliate_cycle ac ON mrp.user_id = ac.user_id
WHERE (mw.referral_amount = 0 OR mw.referral_amount IS NULL)
  AND ac.phase = 'USDT';  -- USDTフェーズなら紹介報酬も出金できるはず
