-- ========================================
-- 12月出金の紹介報酬が累計になっている問題を調査
-- ========================================
-- 実行日: 2026-01-09
-- 問題: 12月の月末出金管理画面で紹介報酬が累計になっている？
-- ========================================

-- ========================================
-- 1. 12月の出金レコードと内訳を確認
-- ========================================
SELECT '=== 1. 12月出金レコードの内訳確認 ===' as section;
SELECT
  mw.user_id,
  mw.personal_amount,
  mw.referral_amount,
  mw.total_amount,
  (mw.personal_amount + COALESCE(mw.referral_amount, 0)) as calc_total,
  mw.total_amount - (mw.personal_amount + COALESCE(mw.referral_amount, 0)) as diff,
  ac.available_usdt as current_available,
  ac.cum_usdt as cumulative_referral,
  ac.phase
FROM monthly_withdrawals mw
LEFT JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
ORDER BY mw.referral_amount DESC NULLS LAST
LIMIT 30;

-- ========================================
-- 2. user_referral_profit_monthly の12月データ確認
-- ========================================
SELECT '=== 2. user_referral_profit_monthly 12月データ ===' as section;
SELECT
  user_id,
  SUM(profit_amount) as dec_referral_total,
  COUNT(*) as record_count
FROM user_referral_profit_monthly
WHERE year = 2025 AND month = 12
GROUP BY user_id
ORDER BY SUM(profit_amount) DESC
LIMIT 20;

-- ========================================
-- 3. monthly_referral_profit テーブル（CLAUDE.mdで指定されているテーブル）
-- ========================================
SELECT '=== 3. monthly_referral_profit テーブル確認 ===' as section;
SELECT
  user_id,
  year_month,
  profit_amount
FROM monthly_referral_profit
WHERE year_month = '2025-12'
ORDER BY profit_amount DESC
LIMIT 20;

-- ========================================
-- 4. 特定ユーザーで詳細比較（紹介報酬が多いユーザー）
-- ========================================
SELECT '=== 4. 紹介報酬上位ユーザーの詳細比較 ===' as section;
WITH top_referral_users AS (
  SELECT user_id
  FROM monthly_withdrawals
  WHERE withdrawal_month = '2025-12-01'
    AND referral_amount > 100
  LIMIT 5
)
SELECT
  tru.user_id,
  mw.referral_amount as mw_referral_amount,
  mw.total_amount as mw_total_amount,
  -- user_referral_profit_monthly から12月分
  (SELECT COALESCE(SUM(profit_amount), 0)
   FROM user_referral_profit_monthly
   WHERE user_id = tru.user_id AND year = 2025 AND month = 12) as urpm_dec_total,
  -- user_referral_profit_monthly 全期間
  (SELECT COALESCE(SUM(profit_amount), 0)
   FROM user_referral_profit_monthly
   WHERE user_id = tru.user_id) as urpm_all_total,
  -- monthly_referral_profit から12月分
  (SELECT COALESCE(SUM(profit_amount), 0)
   FROM monthly_referral_profit
   WHERE user_id = tru.user_id AND year_month = '2025-12') as mrp_dec_total,
  -- monthly_referral_profit 全期間
  (SELECT COALESCE(SUM(profit_amount), 0)
   FROM monthly_referral_profit
   WHERE user_id = tru.user_id) as mrp_all_total,
  -- affiliate_cycle
  ac.cum_usdt,
  ac.phase
FROM top_referral_users tru
LEFT JOIN monthly_withdrawals mw ON tru.user_id = mw.user_id AND mw.withdrawal_month = '2025-12-01'
LEFT JOIN affiliate_cycle ac ON tru.user_id = ac.user_id;

-- ========================================
-- 5. 出金レコードのreferral_amountとcum_usdtの相関
-- ========================================
SELECT '=== 5. referral_amount と cum_usdt の相関 ===' as section;
SELECT
  mw.user_id,
  mw.referral_amount,
  ac.cum_usdt,
  CASE
    WHEN ABS(mw.referral_amount - ac.cum_usdt) < 1 THEN '⚠️ 累計と一致'
    ELSE '✅ 異なる'
  END as status
FROM monthly_withdrawals mw
LEFT JOIN affiliate_cycle ac ON mw.user_id = ac.user_id
WHERE mw.withdrawal_month = '2025-12-01'
  AND mw.referral_amount > 0
ORDER BY ABS(mw.referral_amount - ac.cum_usdt) ASC
LIMIT 30;

-- ========================================
-- 6. 11月の出金レコードとの比較
-- ========================================
SELECT '=== 6. 11月と12月の紹介報酬比較 ===' as section;
SELECT
  COALESCE(nov.user_id, dec.user_id) as user_id,
  nov.referral_amount as nov_referral,
  dec.referral_amount as dec_referral,
  COALESCE(dec.referral_amount, 0) - COALESCE(nov.referral_amount, 0) as diff,
  ac.cum_usdt
FROM monthly_withdrawals nov
FULL OUTER JOIN monthly_withdrawals dec ON nov.user_id = dec.user_id AND dec.withdrawal_month = '2025-12-01'
LEFT JOIN affiliate_cycle ac ON COALESCE(nov.user_id, dec.user_id) = ac.user_id
WHERE nov.withdrawal_month = '2025-11-01'
  OR dec.withdrawal_month = '2025-12-01'
ORDER BY dec.referral_amount DESC NULLS LAST
LIMIT 30;

-- ========================================
-- 7. サマリ統計
-- ========================================
SELECT '=== 7. 12月出金サマリ ===' as section;
SELECT
  COUNT(*) as total_users,
  SUM(personal_amount) as total_personal,
  SUM(referral_amount) as total_referral,
  SUM(total_amount) as total_withdrawal,
  SUM(total_amount) - SUM(personal_amount) - SUM(COALESCE(referral_amount, 0)) as unaccounted
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12-01';
