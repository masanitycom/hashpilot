-- ========================================
-- 🚨 本番環境緊急調査・修正スクリプト
-- 7/17不正設定の徹底調査と安全化
-- ========================================

-- STEP 1: 緊急削除 - 7/17の不正データ
BEGIN;

-- 1-1. 7/17の不正設定確認
SELECT 
    '=== 🚨 7/17不正設定の詳細 ===' as emergency_info,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at,
    '誰が作成したか不明' as concern
FROM daily_yield_log
WHERE date = '2025-07-17';

-- 1-2. 7/17の不正利益データ確認
SELECT 
    '=== 🚨 7/17不正利益データの詳細 ===' as emergency_info,
    COUNT(*) as affected_users,
    SUM(daily_profit) as total_illegal_profit,
    MIN(created_at) as first_created,
    MAX(created_at) as last_created
FROM user_daily_profit
WHERE date = '2025-07-17';

-- 1-3. 影響を受けたユーザー一覧
SELECT 
    '=== 🚨 影響ユーザー一覧 ===' as emergency_info,
    user_id,
    daily_profit,
    base_amount,
    created_at
FROM user_daily_profit
WHERE date = '2025-07-17'
ORDER BY daily_profit DESC;

ROLLBACK; -- まず確認のみ、削除は後で実行

-- STEP 2: 自動処理・バッチジョブの調査
-- 2-1. システムログで自動実行の痕跡確認
SELECT 
    '=== 🔍 自動実行の痕跡調査 ===' as investigation,
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
FROM system_logs
WHERE created_at >= '2025-07-17 00:00:00'
AND (
    operation LIKE '%BATCH%' 
    OR operation LIKE '%AUTO%'
    OR operation LIKE '%DAILY_YIELD%'
    OR operation LIKE '%CRON%'
    OR message LIKE '%自動%'
    OR message LIKE '%auto%'
)
ORDER BY created_at;

-- 2-2. Edge Functions実行履歴調査
SELECT 
    '=== 🔍 Edge Functions調査 ===' as investigation,
    *
FROM system_logs
WHERE created_at >= '2025-07-16 00:00:00'
AND (
    message LIKE '%function%'
    OR message LIKE '%edge%'
    OR message LIKE '%execute_daily_batch%'
    OR operation LIKE '%FUNCTION%'
)
ORDER BY created_at DESC;

-- STEP 3: データベース関数の調査
-- 3-1. 危険な自動実行関数の確認
SELECT 
    '=== 🔍 データベース関数調査 ===' as investigation,
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
AND (
    routine_name LIKE '%batch%'
    OR routine_name LIKE '%auto%'
    OR routine_name LIKE '%daily%'
    OR routine_name LIKE '%cron%'
    OR routine_definition LIKE '%execute_daily_batch%'
    OR routine_definition LIKE '%process_daily_yield%'
)
ORDER BY routine_name;

-- 3-2. execute_daily_batch関数の詳細確認
SELECT 
    '=== 🚨 execute_daily_batch関数の内容 ===' as critical_check,
    routine_definition
FROM information_schema.routines
WHERE routine_name = 'execute_daily_batch';

-- STEP 4: 過去データ欠損の原因調査
-- 4-1. 7/6-7/16の期間で作成されるべきだったデータ確認
WITH expected_dates AS (
    SELECT generate_series(
        '2025-07-06'::date,  -- 7A9637の運用開始日
        '2025-07-16'::date,  -- 昨日まで
        '1 day'::interval
    )::date as expected_date
),
yield_settings AS (
    SELECT date, yield_rate, margin_rate, user_rate
    FROM daily_yield_log
    WHERE date BETWEEN '2025-07-06' AND '2025-07-16'
)
SELECT 
    '=== 📊 欠損データ分析 ===' as analysis,
    ed.expected_date,
    ys.yield_rate,
    ys.user_rate,
    CASE 
        WHEN ys.date IS NULL THEN '❌ 設定なし'
        ELSE '✅ 設定あり'
    END as setting_status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM user_daily_profit udp 
            WHERE udp.date = ed.expected_date 
            AND udp.user_id = '7A9637'
        ) THEN '✅ データあり'
        ELSE '❌ データなし'
    END as data_status
FROM expected_dates ed
LEFT JOIN yield_settings ys ON ed.expected_date = ys.date
ORDER BY ed.expected_date;

-- STEP 5: システム設定テーブルの確認
-- 5-1. system_settingsで自動実行が有効か確認
SELECT 
    '=== ⚙️ システム設定確認 ===' as settings_check,
    setting_key,
    setting_value,
    updated_at
FROM system_settings
WHERE setting_key LIKE '%batch%'
OR setting_key LIKE '%auto%'
OR setting_key LIKE '%daily%'
OR setting_key LIKE '%cron%'
ORDER BY setting_key;

-- STEP 6: 最近の管理者操作履歴
-- 6-1. 管理者による操作履歴
SELECT 
    '=== 👤 管理者操作履歴 ===' as admin_check,
    log_type,
    operation,
    user_id,
    message,
    created_at
FROM system_logs
WHERE created_at >= '2025-07-16 00:00:00'
AND (
    user_id IN (SELECT user_id FROM admins)
    OR log_type = 'ADMIN'
    OR operation LIKE '%ADMIN%'
)
ORDER BY created_at DESC;

-- 緊急対応メッセージ
SELECT 
    '🚨🚨🚨 緊急調査結果を確認してください 🚨🚨🚨' as emergency_message,
    '1. 7/17の不正設定・データの削除が必要' as action1,
    '2. 自動処理の即座停止が必要' as action2,
    '3. 過去データの復旧が必要' as action3,
    '4. 根本原因の特定と修正が必要' as action4;