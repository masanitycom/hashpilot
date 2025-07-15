-- 🚨 最終システム安全確認（READ ONLY - 変更なし）
-- この確認は既存システムに一切変更を加えません

-- 1. ⭐ 日利データの保存状況確認
SELECT 
    '📊 日利データ保存状況:' as check_name,
    COUNT(*) as total_records,
    COUNT(DISTINCT user_id) as users_with_profits,
    COUNT(DISTINCT date) as days_with_data,
    MIN(date) as earliest_date,
    MAX(date) as latest_date,
    SUM(daily_profit::DECIMAL) as total_distributed_profit
FROM user_daily_profit;

-- 2. ⭐ 月末処理機能の存在確認
SELECT 
    '🎯 月末処理関数:' as check_name,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as parameters,
    p.prosrc LIKE '%month%end%' OR p.prosrc LIKE '%is_month_end%' as has_month_end_logic
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
AND (
    p.proname LIKE '%daily%yield%' 
    OR p.proname LIKE '%batch%'
    OR p.proname LIKE '%month%'
)
ORDER BY p.proname;

-- 3. ⭐ 自動NFT購入システムの確認
SELECT 
    '🎪 自動NFT購入システム:' as check_name,
    COUNT(*) as total_auto_purchases,
    SUM(amount_usd::DECIMAL) as total_auto_amount,
    COUNT(DISTINCT user_id) as users_with_auto_purchases,
    MIN(created_at) as first_auto_purchase,
    MAX(created_at) as latest_auto_purchase
FROM purchases 
WHERE is_auto_purchase = true;

-- 4. ⭐ サイクル処理データの確認
SELECT 
    '🔄 サイクル処理状況:' as check_name,
    COUNT(*) as total_users_in_cycle,
    COUNT(CASE WHEN available_usdt > 0 THEN 1 END) as users_with_available_usdt,
    SUM(available_usdt::DECIMAL) as total_available_usdt,
    COUNT(CASE WHEN cum_usdt >= 1100 THEN 1 END) as users_ready_for_action,
    COUNT(CASE WHEN next_action = 'usdt' THEN 1 END) as usdt_phase_users,
    COUNT(CASE WHEN next_action = 'nft' THEN 1 END) as nft_phase_users
FROM affiliate_cycle;

-- 5. ⭐ 出金管理システムの確認
SELECT 
    '💸 出金管理システム:' as check_name,
    COUNT(*) as total_withdrawal_requests,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_requests,
    COUNT(CASE WHEN status = 'approved' THEN 1 END) as approved_requests,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_requests,
    SUM(CASE WHEN status = 'pending' THEN amount::DECIMAL ELSE 0 END) as pending_amount,
    SUM(CASE WHEN status = 'approved' THEN amount::DECIMAL ELSE 0 END) as approved_amount
FROM withdrawal_requests;

-- 6. ⭐ システム設定の確認
SELECT 
    '⚙️ システム設定:' as check_name,
    setting_key,
    setting_value,
    updated_at
FROM system_settings
WHERE setting_key IN (
    'daily_batch_enabled',
    'daily_batch_time',
    'default_yield_rate',
    'default_margin_rate'
)
ORDER BY setting_key;

-- 7. ⭐ 最新の日利設定確認
SELECT 
    '📋 最新日利設定:' as check_name,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
FROM daily_yield_log
ORDER BY date DESC
LIMIT 5;

-- 8. ⭐ システムヘルスチェック実行
SELECT system_health_check() as system_health_status;

-- 9. ⭐ 重要テーブルのレコード数確認
SELECT 
    '📊 テーブル統計:' as check_name,
    'users' as table_name,
    COUNT(*) as record_count,
    COUNT(CASE WHEN is_active = true THEN 1 END) as active_count
FROM users
UNION ALL
SELECT 
    '📊 テーブル統計:' as check_name,
    'purchases' as table_name,
    COUNT(*) as record_count,
    COUNT(CASE WHEN admin_approved = true THEN 1 END) as active_count
FROM purchases
UNION ALL
SELECT 
    '📊 テーブル統計:' as check_name,
    'user_daily_profit' as table_name,
    COUNT(*) as record_count,
    COUNT(DISTINCT user_id) as active_count
FROM user_daily_profit
UNION ALL
SELECT 
    '📊 テーブル統計:' as check_name,
    'affiliate_cycle' as table_name,
    COUNT(*) as record_count,
    COUNT(CASE WHEN total_nft_count > 0 THEN 1 END) as active_count
FROM affiliate_cycle;

-- 10. ⭐ 最新システムログ確認
SELECT 
    '📝 最新システムログ:' as check_name,
    log_type,
    operation,
    message,
    created_at
FROM system_logs
ORDER BY created_at DESC
LIMIT 10;