-- 全ユーザーの出金データ完全削除
-- ダッシュボードの$88.08問題を解決

-- ========================================
-- 1. 削除前の状況確認
-- ========================================
SELECT 
    'BEFORE_DELETE' as phase,
    COUNT(*) as total_records,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_count,
    COUNT(CASE WHEN status = 'on_hold' THEN 1 END) as on_hold_count,
    COALESCE(SUM(total_amount), 0) as total_amount
FROM monthly_withdrawals;

-- ========================================
-- 2. 全出金データを完全削除
-- ========================================

-- monthly_withdrawalsテーブルを完全削除
DELETE FROM monthly_withdrawals;

-- user_withdrawal_settingsテーブルを完全削除
DELETE FROM user_withdrawal_settings;

-- buyback_requestsテーブルを完全削除
DELETE FROM buyback_requests;

-- ========================================
-- 3. 削除後の確認
-- ========================================
SELECT 
    'AFTER_DELETE' as phase,
    (SELECT COUNT(*) FROM monthly_withdrawals) as monthly_withdrawals_count,
    (SELECT COUNT(*) FROM user_withdrawal_settings) as user_withdrawal_settings_count,
    (SELECT COUNT(*) FROM buyback_requests) as buyback_requests_count;

-- ========================================
-- 4. ダッシュボード確認用
-- ========================================
SELECT 
    'DASHBOARD_CHECK' as check_type,
    (SELECT COALESCE(SUM(available_usdt), 0) FROM affiliate_cycle) as total_available_usdt,
    (SELECT COALESCE(MAX(available_usdt), 0) FROM affiliate_cycle) as max_available_usdt,
    (SELECT COUNT(*) FROM monthly_withdrawals) as withdrawal_records;

-- ========================================
-- 5. 完了ログ
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
    'delete_all_withdrawal_data',
    NULL,
    '全ユーザーの出金データを完全削除しました（ダッシュボード$88.08問題解決）',
    jsonb_build_object(
        'deleted_tables', ARRAY['monthly_withdrawals', 'user_withdrawal_settings', 'buyback_requests'],
        'reason', '全ユーザー対象のダッシュボード表示問題解決'
    ),
    NOW()
);

SELECT 
    '🎉 全出金データ削除完了 🎉' as result,
    '全ユーザーのダッシュボードから出金状況が消去されました' as status;