-- ========================================
-- 2025年12月の月次紹介報酬計算
-- ========================================
-- 実行日: 2026年1月1日
--
-- このスクリプトで12月の紹介報酬を計算します。
--
-- 実行手順:
-- 1. まずSTEP 1で現状確認
-- 2. 問題なければSTEP 2で紹介報酬計算を実行
-- ========================================

-- ========================================
-- STEP 1: 現状確認（先に実行）
-- ========================================

-- 1-1. 12月の日利データ確認
SELECT '=== 1-1. 12月の日利データ数 ===' as section;

SELECT
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as user_count,
    SUM(daily_profit) as total_profit,
    MIN(date) as min_date,
    MAX(date) as max_date
FROM user_daily_profit
WHERE date >= '2025-12-01'
  AND date <= '2025-12-31';

-- 1-2. 既に12月の紹介報酬が計算されているか確認
SELECT '=== 1-2. 12月の紹介報酬レコード確認 ===' as section;

SELECT
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as user_count,
    SUM(profit_amount) as total_referral
FROM user_referral_profit_monthly
WHERE year = 2025
  AND month = 12;

-- 1-3. プラス日利のユーザー数（紹介報酬計算対象）
SELECT '=== 1-3. 12月プラス日利ユーザー（紹介報酬対象） ===' as section;

SELECT
    COUNT(DISTINCT user_id) as user_count,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date >= '2025-12-01'
  AND date <= '2025-12-31'
  AND daily_profit > 0;


-- ========================================
-- STEP 2: 12月の紹介報酬計算を実行
-- ========================================
-- 上記の確認結果が問題なければ、以下を実行してください。

-- 2-1. 紹介報酬計算を実行
SELECT '=== 2-1. 12月の紹介報酬計算開始 ===' as section;

SELECT * FROM process_monthly_referral_reward(2025, 12, FALSE);

-- 既に計算済みの場合、上書きする場合は以下を使用:
-- SELECT * FROM process_monthly_referral_reward(2025, 12, TRUE);


-- ========================================
-- STEP 3: 結果確認
-- ========================================

-- 3-1. 計算結果確認
SELECT '=== 3-1. 12月紹介報酬計算結果 ===' as section;

SELECT
    referral_level,
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as user_count,
    SUM(profit_amount) as total_profit
FROM user_referral_profit_monthly
WHERE year = 2025
  AND month = 12
GROUP BY referral_level
ORDER BY referral_level;

-- 3-2. ユーザー別紹介報酬（上位20名）
SELECT '=== 3-2. 12月紹介報酬ユーザー別（上位20名） ===' as section;

SELECT
    user_id,
    SUM(CASE WHEN referral_level = 1 THEN profit_amount ELSE 0 END) as level1_profit,
    SUM(CASE WHEN referral_level = 2 THEN profit_amount ELSE 0 END) as level2_profit,
    SUM(CASE WHEN referral_level = 3 THEN profit_amount ELSE 0 END) as level3_profit,
    SUM(profit_amount) as total_profit
FROM user_referral_profit_monthly
WHERE year = 2025
  AND month = 12
GROUP BY user_id
ORDER BY total_profit DESC
LIMIT 20;
