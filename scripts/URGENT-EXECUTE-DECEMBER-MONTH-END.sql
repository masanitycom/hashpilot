-- ========================================
-- 🚨 緊急: 2025年12月の月末処理を実行
-- ========================================
-- 実行日: 2026年1月1日
--
-- 2つの処理を実行する必要があります:
-- 1. 紹介報酬計算
-- 2. 月末出金処理
-- ========================================

-- ========================================
-- STEP 1: 現状確認
-- ========================================

-- 1-1. 12月の日利データ確認
SELECT '=== 1-1. 12月の日利データ ===' as section;
SELECT
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as user_count,
    SUM(daily_profit) as total_profit,
    MIN(date) as min_date,
    MAX(date) as max_date
FROM user_daily_profit
WHERE date >= '2025-12-01' AND date <= '2025-12-31';

-- 1-2. 12月の紹介報酬（既存）
SELECT '=== 1-2. 12月の紹介報酬（既存） ===' as section;
SELECT
    COUNT(*) as record_count,
    SUM(profit_amount) as total_referral
FROM user_referral_profit_monthly
WHERE year = 2025 AND month = 12;

-- 1-3. 12月の出金データ（既存）
SELECT '=== 1-3. 12月の出金データ（既存） ===' as section;
SELECT
    status,
    COUNT(*) as count,
    SUM(total_amount) as total
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12'
GROUP BY status;


-- ========================================
-- STEP 2: 紹介報酬計算を実行
-- ========================================
-- 既にデータがある場合は上書きするか確認

SELECT '=== STEP 2: 紹介報酬計算実行 ===' as section;

-- 初回実行（既存データがない場合）
SELECT * FROM process_monthly_referral_reward(2025, 12, FALSE);

-- もし「既に計算済み」エラーが出たら、以下を実行（上書き）:
-- SELECT * FROM process_monthly_referral_reward(2025, 12, TRUE);


-- ========================================
-- STEP 3: 月末出金処理を実行
-- ========================================

SELECT '=== STEP 3: 月末出金処理実行 ===' as section;

-- 12月分の月末出金を生成
SELECT * FROM process_monthly_withdrawals('2025-12-01'::DATE);


-- ========================================
-- STEP 4: 結果確認
-- ========================================

-- 4-1. 紹介報酬結果
SELECT '=== 4-1. 紹介報酬結果 ===' as section;
SELECT
    referral_level,
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as user_count,
    SUM(profit_amount) as total_profit
FROM user_referral_profit_monthly
WHERE year = 2025 AND month = 12
GROUP BY referral_level
ORDER BY referral_level;

-- 4-2. 出金データ結果
SELECT '=== 4-2. 出金データ結果 ===' as section;
SELECT
    status,
    COUNT(*) as count,
    SUM(total_amount) as total_amount,
    SUM(personal_amount) as personal_total,
    SUM(referral_amount) as referral_total
FROM monthly_withdrawals
WHERE withdrawal_month = '2025-12'
GROUP BY status;

-- 4-3. 出金対象ユーザー一覧（上位20名）
SELECT '=== 4-3. 出金対象ユーザー（上位20名） ===' as section;
SELECT
    mw.user_id,
    u.email,
    mw.total_amount,
    mw.personal_amount,
    mw.referral_amount,
    mw.status,
    mw.withdrawal_address
FROM monthly_withdrawals mw
JOIN users u ON mw.user_id = u.user_id
WHERE mw.withdrawal_month = '2025-12'
ORDER BY mw.total_amount DESC
LIMIT 20;
