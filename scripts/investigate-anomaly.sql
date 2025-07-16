-- =====================================
-- 緊急調査: daily_yield_log 異常設定の調査
-- =====================================

\echo '=== DAILY YIELD LOG 全履歴 ==='
-- 日利設定ログの全履歴を時系列で確認
SELECT 
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at,
    created_by,
    admin_user_id,
    notes
FROM daily_yield_log
ORDER BY created_at DESC
LIMIT 50;

\echo '=== 異常なマージン率の設定 ==='
-- 3000%のマージン率設定を特定
SELECT 
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at,
    created_by,
    admin_user_id,
    notes,
    CASE 
        WHEN margin_rate > 100 THEN 'ANOMALY'
        ELSE 'NORMAL'
    END as status
FROM daily_yield_log
WHERE margin_rate > 100
ORDER BY created_at DESC;

\echo '=== 設定作成パターン分析 ==='
-- 設定作成の時間パターンを分析
SELECT 
    DATE(created_at) as creation_date,
    COUNT(*) as creation_count,
    AVG(margin_rate) as avg_margin_rate,
    MAX(margin_rate) as max_margin_rate,
    MIN(margin_rate) as min_margin_rate,
    STRING_AGG(DISTINCT created_by, ', ') as creators
FROM daily_yield_log
GROUP BY DATE(created_at)
ORDER BY creation_date DESC;

\echo '=== 作成者別分析 ==='
-- 誰がどのような設定を作成したかを分析
SELECT 
    created_by,
    admin_user_id,
    COUNT(*) as creation_count,
    AVG(margin_rate) as avg_margin_rate,
    MAX(margin_rate) as max_margin_rate,
    MIN(created_at) as first_creation,
    MAX(created_at) as last_creation
FROM daily_yield_log
GROUP BY created_by, admin_user_id
ORDER BY creation_count DESC;

\echo '=== システムログの関連操作 ==='
-- システムログで日利設定に関する操作を確認
SELECT 
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
FROM system_logs
WHERE 
    operation LIKE '%yield%' OR 
    operation LIKE '%margin%' OR
    message LIKE '%3000%' OR
    message LIKE '%daily%'
ORDER BY created_at DESC
LIMIT 30;

\echo '=== 自動バッチ処理の履歴 ==='
-- 自動バッチ処理に関するログを確認
SELECT 
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
FROM system_logs
WHERE 
    operation LIKE '%batch%' OR
    operation LIKE '%auto%' OR
    log_type = 'BATCH'
ORDER BY created_at DESC
LIMIT 20;

\echo '=== 管理者アクセスログ ==='
-- 管理者の日利設定画面へのアクセスログ
SELECT 
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
FROM system_logs
WHERE 
    operation LIKE '%admin%' OR
    operation LIKE '%yield%' OR
    user_id IN (
        SELECT user_id FROM admins
    )
ORDER BY created_at DESC
LIMIT 25;

\echo '=== 管理者アカウント一覧 ==='
-- 現在の管理者アカウントを確認
SELECT 
    user_id,
    email,
    role,
    created_at as admin_since
FROM admins
ORDER BY created_at;

\echo '=== 最近のprocess_daily_yield_with_cycles実行 ==='
-- 日利処理関数の実行履歴
SELECT 
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
FROM system_logs
WHERE 
    operation LIKE '%process_daily_yield%' OR
    message LIKE '%process_daily_yield%'
ORDER BY created_at DESC
LIMIT 15;