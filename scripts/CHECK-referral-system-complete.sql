-- =============================================
-- 紹介報酬システム完全調査
-- =============================================
-- 目的: 紹介報酬に関するテーブル・関数の現状を把握
-- 実行: Supabase SQL Editorで実行
-- =============================================

-- =============================================
-- 1. 紹介報酬関連テーブルの存在確認
-- =============================================
SELECT '=== 1. 紹介報酬関連テーブル一覧 ===' as section;

SELECT
  table_name,
  CASE
    WHEN table_name = 'user_referral_profit' THEN '❌ 旧・日次紹介報酬（廃止予定）'
    WHEN table_name = 'user_referral_profit_monthly' THEN '？ 月次紹介報酬（要確認）'
    WHEN table_name = 'monthly_referral_profit' THEN '✅ 月次紹介報酬（CLAUDE.md記載）'
    ELSE '？ 要確認'
  END as status
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name LIKE '%referral%'
ORDER BY table_name;

-- =============================================
-- 2. 各テーブルのレコード数
-- =============================================
SELECT '=== 2. 各テーブルのレコード数 ===' as section;

SELECT 'user_referral_profit' as table_name, COUNT(*) as record_count
FROM user_referral_profit
UNION ALL
SELECT 'monthly_referral_profit', COUNT(*)
FROM monthly_referral_profit;

-- user_referral_profit_monthlyが存在する場合
-- SELECT 'user_referral_profit_monthly', COUNT(*)
-- FROM user_referral_profit_monthly;

-- =============================================
-- 3. 日次紹介報酬（user_referral_profit）の内容
-- =============================================
SELECT '=== 3. user_referral_profit の内容サンプル ===' as section;

SELECT
  date,
  COUNT(*) as records,
  SUM(profit_amount) as total_amount
FROM user_referral_profit
GROUP BY date
ORDER BY date DESC
LIMIT 10;

-- =============================================
-- 4. 月次紹介報酬（monthly_referral_profit）の内容
-- =============================================
SELECT '=== 4. monthly_referral_profit の内容サンプル ===' as section;

SELECT
  year,
  month,
  COUNT(*) as records,
  SUM(profit_amount) as total_amount
FROM monthly_referral_profit
GROUP BY year, month
ORDER BY year DESC, month DESC;

-- =============================================
-- 5. 紹介報酬関連のRPC関数一覧
-- =============================================
SELECT '=== 5. 紹介報酬関連のRPC関数 ===' as section;

SELECT
  routine_name as function_name,
  routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND (routine_name LIKE '%referral%' OR routine_name LIKE '%daily_yield%')
ORDER BY routine_name;

-- =============================================
-- 6. process_daily_yield_v2の定義確認
-- =============================================
SELECT '=== 6. process_daily_yield_v2 の定義 ===' as section;

SELECT
  pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname = 'process_daily_yield_v2'
LIMIT 1;

-- =============================================
-- 7. affiliate_cycle.cum_usdtの整合性確認
-- =============================================
SELECT '=== 7. cum_usdt整合性チェック ===' as section;

SELECT
  ac.user_id,
  ac.cum_usdt,
  COALESCE(mrp.monthly_total, 0) as monthly_referral_total,
  COALESCE(urp.daily_total, 0) as daily_referral_total,
  ac.cum_usdt - COALESCE(mrp.monthly_total, 0) as diff_from_monthly,
  ac.cum_usdt - COALESCE(urp.daily_total, 0) as diff_from_daily
FROM affiliate_cycle ac
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as monthly_total
  FROM monthly_referral_profit
  GROUP BY user_id
) mrp ON ac.user_id = mrp.user_id
LEFT JOIN (
  SELECT user_id, SUM(profit_amount) as daily_total
  FROM user_referral_profit
  GROUP BY user_id
) urp ON ac.user_id = urp.user_id
WHERE ac.cum_usdt > 0
ORDER BY ac.cum_usdt DESC
LIMIT 20;

-- =============================================
-- 8. 本日（1/1）の日次紹介報酬が存在するか
-- =============================================
SELECT '=== 8. 2026年1月の日次紹介報酬 ===' as section;

SELECT
  date,
  COUNT(*) as records,
  SUM(profit_amount) as total_amount
FROM user_referral_profit
WHERE date >= '2026-01-01'
GROUP BY date
ORDER BY date;

-- =============================================
-- 9. daily_yield_log_v2の返却値確認
-- =============================================
SELECT '=== 9. daily_yield_log_v2 の最新レコード ===' as section;

SELECT
  date,
  total_profit_amount,
  total_nft_count,
  distribution_dividend,
  distribution_affiliate,
  distribution_stock
FROM daily_yield_log_v2
ORDER BY date DESC
LIMIT 5;

-- =============================================
-- まとめ
-- =============================================
SELECT '=== まとめ ===' as section;
SELECT '上記の結果を確認して、以下を判断:' as note
UNION ALL
SELECT '1. user_referral_profitに日次データがあるか → あれば日次紹介報酬が動いている'
UNION ALL
SELECT '2. monthly_referral_profitにデータがあるか → あれば月次紹介報酬が動いている'
UNION ALL
SELECT '3. cum_usdtがどちらと一致するか → どちらを使っているか判断';
