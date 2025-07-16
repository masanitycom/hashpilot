-- 🔍 7/11の設定値を復元
-- 2025年7月17日

-- 1. システムログから7/11の設定を検索
SELECT 
    '7/11システムログ検索' as check_type,
    log_type,
    operation,
    message,
    details,
    created_at
FROM system_logs 
WHERE (message LIKE '%2025-07-11%' OR details->>'date' = '2025-07-11')
ORDER BY created_at DESC;

-- 2. 全システムログから7/11関連を検索
SELECT 
    '7/11関連ログ' as check_type,
    log_type,
    operation,
    message,
    details,
    created_at
FROM system_logs 
WHERE message LIKE '%11%' OR details::text LIKE '%11%'
ORDER BY created_at DESC;

-- 3. 最近のエラーログを確認
SELECT 
    '最近のエラーログ' as check_type,
    log_type,
    operation,
    message,
    details,
    created_at
FROM system_logs 
WHERE log_type = 'ERROR'
ORDER BY created_at DESC
LIMIT 10;

-- 4. 日利処理の全履歴
SELECT 
    '日利処理履歴' as check_type,
    log_type,
    operation,
    message,
    details,
    created_at
FROM system_logs 
WHERE operation LIKE '%daily_yield%'
ORDER BY created_at DESC
LIMIT 20;