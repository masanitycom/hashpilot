-- =============================================
-- 2026/1/1の日次紹介報酬を削除
-- =============================================
-- 問題: process_daily_yield_v2に日次紹介報酬処理が含まれていたため、
--       1/1の日利設定時に$359.97の日次紹介報酬が誤って配布された
--
-- 対処:
--   1. user_referral_profitから1/1のデータを削除
--   2. affiliate_cycleのcum_usdtとavailable_usdtを修正
-- =============================================

-- STEP 1: 影響を受けるユーザーと金額を確認
SELECT '=== STEP 1: 影響確認 ===' as section;

SELECT
  user_id,
  SUM(profit_amount) as total_referral
FROM user_referral_profit
WHERE date = '2026-01-01'
GROUP BY user_id
ORDER BY total_referral DESC
LIMIT 20;

-- 合計金額
SELECT
  COUNT(DISTINCT user_id) as affected_users,
  COUNT(*) as total_records,
  SUM(profit_amount) as total_amount
FROM user_referral_profit
WHERE date = '2026-01-01';

-- STEP 2: affiliate_cycleからcum_usdtとavailable_usdtを差し引く
SELECT '=== STEP 2: affiliate_cycle修正 ===' as section;

-- 各ユーザーの1/1紹介報酬合計を計算して差し引く
UPDATE affiliate_cycle ac
SET
  cum_usdt = ac.cum_usdt - urp.total_referral,
  available_usdt = ac.available_usdt - urp.total_referral,
  updated_at = NOW()
FROM (
  SELECT
    user_id,
    SUM(profit_amount) as total_referral
  FROM user_referral_profit
  WHERE date = '2026-01-01'
  GROUP BY user_id
) urp
WHERE ac.user_id = urp.user_id;

-- 更新件数を確認
SELECT '更新後のaffiliate_cycle確認' as note;
SELECT
  SUM(cum_usdt) as total_cum_usdt,
  SUM(available_usdt) as total_available_usdt
FROM affiliate_cycle;

-- STEP 3: user_referral_profitから1/1のデータを削除
SELECT '=== STEP 3: user_referral_profit削除 ===' as section;

DELETE FROM user_referral_profit
WHERE date = '2026-01-01';

-- 削除後の確認
SELECT '削除後の確認' as note;
SELECT
  COUNT(*) as remaining_records
FROM user_referral_profit
WHERE date = '2026-01-01';

-- STEP 4: 最終確認
SELECT '=== STEP 4: 最終確認 ===' as section;

SELECT
  'user_referral_profit' as table_name,
  COUNT(*) as count
FROM user_referral_profit
UNION ALL
SELECT
  'affiliate_cycle total_cum_usdt',
  SUM(cum_usdt)::bigint
FROM affiliate_cycle;
