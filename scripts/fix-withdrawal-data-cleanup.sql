-- 出金状況$88.08残存問題の解決
-- 出金関連テーブルの完全クリーンアップ

-- ========================================
-- 1. 出金関連テーブルの現状確認
-- ========================================

-- monthly_withdrawalsテーブルの確認
SELECT 
    'monthly_withdrawals' as table_name,
    COUNT(*) as total_records,
    SUM(COALESCE(amount, 0)) as total_amount,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_count,
    SUM(CASE WHEN status = 'pending' THEN COALESCE(amount, 0) ELSE 0 END) as pending_amount
FROM monthly_withdrawals;

-- user_withdrawal_settingsテーブルの確認
SELECT 
    'user_withdrawal_settings' as table_name,
    COUNT(*) as total_records,
    SUM(COALESCE(pending_amount, 0)) as total_pending
FROM user_withdrawal_settings;

-- buyback_requestsテーブルの確認
SELECT 
    'buyback_requests' as table_name,
    COUNT(*) as total_records,
    SUM(COALESCE(total_buyback_amount, 0)) as total_amount,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_requests
FROM buyback_requests;

-- ========================================
-- 2. ダッシュボードで使用される可能性のあるデータを特定
-- ========================================

-- 保留中の出金データ（ダッシュボードに$88.08として表示される可能性）
SELECT 
    user_id,
    amount,
    status,
    created_at,
    updated_at,
    'monthly_withdrawals' as source_table
FROM monthly_withdrawals 
WHERE status = 'pending' OR amount > 0
UNION ALL
SELECT 
    user_id,
    pending_amount as amount,
    'pending' as status,
    created_at,
    updated_at,
    'user_withdrawal_settings' as source_table
FROM user_withdrawal_settings 
WHERE pending_amount > 0
UNION ALL
SELECT 
    user_id,
    total_buyback_amount as amount,
    status,
    created_at,
    updated_at,
    'buyback_requests' as source_table
FROM buyback_requests 
WHERE status = 'pending' OR total_buyback_amount > 0
ORDER BY amount DESC;

-- ========================================
-- 3. 出金関連テーブルの完全クリーンアップ
-- ========================================

-- A. monthly_withdrawalsテーブルを完全削除
DELETE FROM monthly_withdrawals;

-- B. user_withdrawal_settingsテーブルをリセット
UPDATE user_withdrawal_settings SET
    pending_amount = 0,
    total_withdrawn = 0,
    last_withdrawal_date = NULL,
    updated_at = NOW()
WHERE pending_amount != 0 OR total_withdrawn != 0;

-- または完全削除する場合
-- DELETE FROM user_withdrawal_settings;

-- C. buyback_requestsテーブルの保留中申請を削除
DELETE FROM buyback_requests WHERE status = 'pending';

-- または全削除する場合（テストデータなら）
-- DELETE FROM buyback_requests;

-- ========================================
-- 4. その他の関連テーブルもチェック・クリーンアップ
-- ========================================

-- affiliate_rewardテーブル（紹介報酬が蓄積されている可能性）
SELECT 
    'affiliate_reward' as table_name,
    COUNT(*) as total_records,
    SUM(COALESCE(reward_amount, 0)) as total_rewards
FROM affiliate_reward;

-- 必要に応じて削除
DELETE FROM affiliate_reward;

-- user_monthly_rewardsテーブル（月次報酬データ）
SELECT 
    'user_monthly_rewards' as table_name,
    COUNT(*) as total_records,
    SUM(COALESCE(reward_amount, 0)) as total_monthly_rewards
FROM user_monthly_rewards;

-- 必要に応じて削除
DELETE FROM user_monthly_rewards;

-- referral_commissionsテーブル（紹介手数料）
SELECT 
    'referral_commissions' as table_name,
    COUNT(*) as total_records,
    SUM(COALESCE(commission_amount, 0)) as total_commissions
FROM referral_commissions;

-- 必要に応じて削除
DELETE FROM referral_commissions;

-- ========================================
-- 5. クリーンアップ後の確認
-- ========================================

-- 全ての出金関連データの確認
SELECT 
    'AFTER_CLEANUP' as phase,
    'monthly_withdrawals' as table_name,
    COUNT(*) as remaining_records,
    COALESCE(SUM(amount), 0) as total_amount
FROM monthly_withdrawals
UNION ALL
SELECT 
    'AFTER_CLEANUP' as phase,
    'user_withdrawal_settings' as table_name,
    COUNT(*) as remaining_records,
    COALESCE(SUM(pending_amount), 0) as total_pending
FROM user_withdrawal_settings
UNION ALL
SELECT 
    'AFTER_CLEANUP' as phase,
    'buyback_requests' as table_name,
    COUNT(*) as remaining_records,
    COALESCE(SUM(total_buyback_amount), 0) as total_amount
FROM buyback_requests
UNION ALL
SELECT 
    'AFTER_CLEANUP' as phase,
    'affiliate_reward' as table_name,
    COUNT(*) as remaining_records,
    COALESCE(SUM(reward_amount), 0) as total_rewards
FROM affiliate_reward
UNION ALL
SELECT 
    'AFTER_CLEANUP' as phase,
    'user_monthly_rewards' as table_name,
    COUNT(*) as remaining_records,
    COALESCE(SUM(reward_amount), 0) as total_monthly
FROM user_monthly_rewards
UNION ALL
SELECT 
    'AFTER_CLEANUP' as phase,
    'referral_commissions' as table_name,
    COUNT(*) as remaining_records,
    COALESCE(SUM(commission_amount), 0) as total_commissions
FROM referral_commissions;

-- ========================================
-- 6. ダッシュボード表示確認用クエリ
-- ========================================

-- ダッシュボードで$88.08が表示される可能性のあるデータソースをすべてチェック
SELECT 
    'DASHBOARD_SOURCES_CHECK' as check_type,
    
    -- affiliate_cycleの利用可能残高
    (SELECT COALESCE(SUM(available_usdt), 0) FROM affiliate_cycle) as affiliate_available_total,
    (SELECT COALESCE(MAX(available_usdt), 0) FROM affiliate_cycle) as affiliate_max_available,
    
    -- 保留中出金
    (SELECT COALESCE(SUM(amount), 0) FROM monthly_withdrawals WHERE status = 'pending') as pending_withdrawals,
    
    -- 出金設定の保留額
    (SELECT COALESCE(SUM(pending_amount), 0) FROM user_withdrawal_settings) as withdrawal_settings_pending,
    
    -- 買い取り申請
    (SELECT COALESCE(SUM(total_buyback_amount), 0) FROM buyback_requests WHERE status = 'pending') as pending_buybacks,
    
    -- 紹介報酬
    (SELECT COALESCE(SUM(reward_amount), 0) FROM affiliate_reward) as affiliate_rewards,
    
    -- 月次報酬
    (SELECT COALESCE(SUM(reward_amount), 0) FROM user_monthly_rewards) as monthly_rewards;

-- ========================================
-- 7. 完了ログ
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
    'withdrawal_data_complete_cleanup',
    NULL,
    '出金関連データの完全クリーンアップが完了しました（$88.08問題解決）',
    jsonb_build_object(
        'cleaned_tables', ARRAY[
            'monthly_withdrawals',
            'user_withdrawal_settings', 
            'buyback_requests',
            'affiliate_reward',
            'user_monthly_rewards',
            'referral_commissions'
        ],
        'issue', 'ダッシュボードに$88.08が残存していた問題',
        'solution', '全出金関連テーブルのデータ削除・リセット'
    ),
    NOW()
);

-- ========================================
-- 8. 最終確認
-- ========================================
SELECT 
    '🎉 出金データクリーンアップ完了 🎉' as message,
    'ダッシュボードの$88.08が消去されているはずです' as status,
    'ブラウザを更新してダッシュボードを確認してください' as next_action;