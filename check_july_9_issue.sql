-- ========================================
-- 7/9の日利設定問題の調査
-- ========================================

-- 1. daily_yield_logで7/9のデータ確認
SELECT 
    '=== daily_yield_logの7/9データ ===' as check_status,
    date,
    yield_rate * 100 as yield_rate_percent,
    margin_rate * 100 as margin_rate_percent,
    user_rate * 100 as user_rate_percent,
    created_at,
    created_by
FROM daily_yield_log
WHERE date = '2025-07-09'
ORDER BY created_at DESC;

-- 2. 全期間のdaily_yield_log確認
SELECT 
    '=== 全期間の日利設定 ===' as all_settings,
    date,
    yield_rate * 100 as yield_rate_percent,
    margin_rate * 100 as margin_rate_percent,
    user_rate * 100 as user_rate_percent,
    created_at
FROM daily_yield_log
ORDER BY date DESC;

-- 3. user_daily_profitで7/9のデータ確認
SELECT 
    '=== user_daily_profitの7/9データ数 ===' as profit_check,
    COUNT(*) as record_count,
    SUM(daily_profit) as total_profit
FROM user_daily_profit
WHERE date = '2025-07-09';

-- 4. 特定ユーザー（7A9637）の7/9データ確認
SELECT 
    '=== 7A9637の7/9データ ===' as user_check,
    user_id,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount
FROM user_daily_profit
WHERE user_id = '7A9637' AND date = '2025-07-09';

-- 5. 最近の処理ログ確認（もしsystem_logsテーブルがある場合）
SELECT 
    '=== 最近の処理ログ ===' as log_check,
    created_at,
    operation,
    message,
    metadata
FROM system_logs
WHERE operation LIKE '%yield%' 
   OR operation LIKE '%daily%'
   OR message LIKE '%7/9%'
   OR message LIKE '%2025-07-09%'
ORDER BY created_at DESC
LIMIT 10;

-- 6. データベース関数の実行権限確認
SELECT 
    '=== process_daily_yield_with_cycles関数の確認 ===' as function_check,
    proname,
    proowner::regrole as owner,
    proacl as access_privileges
FROM pg_proc
WHERE proname = 'process_daily_yield_with_cycles';

-- 7. 手動で7/9のデータを作成（必要な場合）
-- もしdaily_yield_logにデータがあるがuser_daily_profitにない場合
/*
INSERT INTO user_daily_profit (
    user_id, 
    date, 
    daily_profit, 
    yield_rate, 
    user_rate, 
    base_amount, 
    phase,
    created_at
)
SELECT 
    ac.user_id,
    '2025-07-09' as date,
    (ac.total_nft_count * 1100 * yl.user_rate) as daily_profit,
    yl.yield_rate,
    yl.user_rate,
    (ac.total_nft_count * 1100) as base_amount,
    CASE 
        WHEN ac.cum_usdt < 1100 THEN 'USDT'
        ELSE 'HOLD'
    END as phase,
    NOW() as created_at
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
CROSS JOIN (
    SELECT yield_rate, user_rate 
    FROM daily_yield_log 
    WHERE date = '2025-07-09'
    LIMIT 1
) yl
WHERE u.has_approved_nft = true 
  AND ac.total_nft_count > 0
ON CONFLICT (user_id, date) DO NOTHING;
*/