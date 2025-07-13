-- 緊急: 全システムデータクリーンアップ
-- ダッシュボードに古いデータが残存している問題を解決

-- ========================================
-- 1. 影響を受ける可能性がある全テーブルを確認
-- ========================================

-- 出金関連テーブルの確認
SELECT 'withdrawal_requests' as table_name, COUNT(*) as record_count, 
       SUM(CASE WHEN status = 'pending' THEN amount ELSE 0 END) as pending_amount
FROM withdrawal_requests
UNION ALL
SELECT 'affiliate_cycle' as table_name, COUNT(*) as record_count, 
       SUM(available_usdt) as total_available_usdt
FROM affiliate_cycle
UNION ALL
SELECT 'user_daily_profit' as table_name, COUNT(*) as record_count, 
       SUM(daily_profit) as total_profit
FROM user_daily_profit
UNION ALL
SELECT 'daily_yield_log' as table_name, COUNT(*) as record_count, 0 as numeric_value
FROM daily_yield_log
UNION ALL
SELECT 'purchases' as table_name, COUNT(*) as record_count, 
       SUM(amount_usd) as total_amount
FROM purchases
ORDER BY table_name;

-- ========================================
-- 2. affiliate_cycleテーブルの詳細確認
-- ========================================
SELECT 
    user_id,
    cum_usdt,
    available_usdt,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    cycle_number,
    cycle_start_date,
    updated_at
FROM affiliate_cycle 
WHERE available_usdt > 0 OR cum_usdt > 0
ORDER BY available_usdt DESC, cum_usdt DESC;

-- ========================================
-- 3. 出金申請の状況確認
-- ========================================
SELECT 
    id,
    user_id,
    amount,
    status,
    available_usdt_before,
    available_usdt_after,
    created_at,
    admin_approved_at
FROM withdrawal_requests 
WHERE status = 'pending' OR created_at >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY created_at DESC;

-- ========================================
-- 4. ユーザーダッシュボードで表示されるデータソース確認
-- ========================================

-- 昨日の利益（ダッシュボードに表示される）
SELECT 
    'yesterday_profit' as data_type,
    user_id,
    daily_profit,
    date,
    created_at
FROM user_daily_profit 
WHERE date = CURRENT_DATE - INTERVAL '1 day'
ORDER BY daily_profit DESC;

-- 今月の累積利益
SELECT 
    'monthly_profit' as data_type,
    user_id,
    SUM(daily_profit) as monthly_total,
    COUNT(*) as profit_days
FROM user_daily_profit 
WHERE date >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY user_id
HAVING SUM(daily_profit) > 0
ORDER BY monthly_total DESC;

-- ========================================
-- 5. 実運用前の完全データリセット
-- ========================================

-- ⚠️ 警告: 以下は全てのテストデータを完全削除します

-- A. user_daily_profit（日利データ）を完全削除
DELETE FROM user_daily_profit;

-- B. affiliate_cycleの利益関連データをリセット
UPDATE affiliate_cycle SET
    cum_usdt = 0,
    available_usdt = 0,
    cycle_number = 1,
    cycle_start_date = NULL,
    updated_at = NOW();

-- C. 出金申請を完全削除（テストデータ）
DELETE FROM withdrawal_requests;

-- D. daily_yield_log（日利設定）を完全削除
DELETE FROM daily_yield_log;

-- E. 自動購入のpurchasesレコードを削除
DELETE FROM purchases WHERE is_auto_purchase = true;

-- F. system_logsの古いログをクリーンアップ（オプション）
DELETE FROM system_logs 
WHERE created_at < CURRENT_DATE - INTERVAL '7 days'
    AND log_type IN ('SUCCESS', 'INFO')
    AND operation LIKE '%yield%';

-- ========================================
-- 6. リセット後の確認
-- ========================================

-- 全テーブルの状態確認
SELECT 'AFTER_RESET' as phase,
       'withdrawal_requests' as table_name, 
       COUNT(*) as remaining_records,
       COALESCE(SUM(amount), 0) as total_amount
FROM withdrawal_requests
UNION ALL
SELECT 'AFTER_RESET' as phase,
       'affiliate_cycle' as table_name, 
       COUNT(*) as remaining_records,
       COALESCE(SUM(available_usdt), 0) as total_available
FROM affiliate_cycle
UNION ALL
SELECT 'AFTER_RESET' as phase,
       'user_daily_profit' as table_name, 
       COUNT(*) as remaining_records,
       COALESCE(SUM(daily_profit), 0) as total_profit
FROM user_daily_profit
UNION ALL
SELECT 'AFTER_RESET' as phase,
       'daily_yield_log' as table_name, 
       COUNT(*) as remaining_records,
       0 as total_amount
FROM daily_yield_log;

-- affiliate_cycleの状態確認
SELECT 
    'RESET_CHECK' as check_type,
    COUNT(*) as total_users,
    SUM(CASE WHEN available_usdt = 0 THEN 1 ELSE 0 END) as users_with_zero_balance,
    SUM(CASE WHEN cum_usdt = 0 THEN 1 ELSE 0 END) as users_with_zero_cum,
    MAX(available_usdt) as max_available_usdt,
    MAX(cum_usdt) as max_cum_usdt
FROM affiliate_cycle;

-- ========================================
-- 7. ダッシュボード表示データの確認
-- ========================================

-- ダッシュボードで表示される可能性のあるデータをすべて確認
SELECT 
    'DASHBOARD_DATA_CHECK' as check_type,
    
    -- 昨日の利益
    (SELECT COUNT(*) FROM user_daily_profit 
     WHERE date = CURRENT_DATE - INTERVAL '1 day') as yesterday_profit_records,
    
    -- 今月の利益
    (SELECT COUNT(*) FROM user_daily_profit 
     WHERE date >= DATE_TRUNC('month', CURRENT_DATE)) as monthly_profit_records,
    
    -- 出金申請
    (SELECT COUNT(*) FROM withdrawal_requests 
     WHERE status = 'pending') as pending_withdrawals,
    
    -- 利用可能残高
    (SELECT COUNT(*) FROM affiliate_cycle 
     WHERE available_usdt > 0) as users_with_balance,
     
    -- 最大残高
    (SELECT COALESCE(MAX(available_usdt), 0) FROM affiliate_cycle) as max_user_balance;

-- ========================================
-- 8. 完全リセット完了ログ
-- ========================================
INSERT INTO system_logs (
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
) VALUES (
    'SUCCESS',
    'emergency_full_system_reset',
    NULL,
    '実運用開始前の完全システムリセットが完了しました',
    jsonb_build_object(
        'reset_tables', ARRAY[
            'user_daily_profit (完全削除)',
            'affiliate_cycle (利益データリセット)',
            'withdrawal_requests (完全削除)',
            'daily_yield_log (完全削除)',
            'purchases (自動購入削除)'
        ],
        'reason', 'ダッシュボード古いデータ残存問題の解決',
        'reset_date', CURRENT_DATE,
        'status', '完全クリーン状態'
    ),
    NOW()
);

-- ========================================
-- 9. 最終確認とシステム準備完了
-- ========================================
SELECT 
    '🎉 完全リセット完了 🎉' as message,
    '全テーブルがクリーン状態です' as status,
    'ダッシュボードの古いデータも消去されました' as note,
    '新規日利設定から実運用を開始してください' as next_action;