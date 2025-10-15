-- ========================================
-- 全システム機能の包括的チェック
-- 2025年10月15日 本番運用開始
-- ========================================

-- 1. 購入承認機能（approve_user_nft）のチェック
SELECT '=== 1. 購入承認機能（approve_user_nft） ===' as check_section;

-- 関数の存在確認
SELECT
    proname as function_name,
    pronargs as arg_count,
    pg_get_function_result(oid) as return_type
FROM pg_proc
WHERE proname = 'approve_user_nft';

-- ON CONFLICT句が無いことを確認（重要）
SELECT
    CASE
        WHEN pg_get_functiondef(oid) LIKE '%ON CONFLICT%' THEN '❌ ON CONFLICT句が存在します（要修正）'
        ELSE '✅ ON CONFLICT句は削除されています'
    END as conflict_check
FROM pg_proc
WHERE proname = 'approve_user_nft'
LIMIT 1;

-- 2. 紹介者変更機能のチェック
SELECT '=== 2. 紹介者変更機能 ===' as check_section;

-- update_user_referrerなどの関数確認
SELECT proname, pronargs
FROM pg_proc
WHERE proname LIKE '%referrer%' OR proname LIKE '%update_user%'
ORDER BY proname;

-- usersテーブルのreferrer_user_idカラム確認
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'users' AND column_name = 'referrer_user_id';

-- 3. 日利計算システム（process_daily_yield_with_cycles）のチェック
SELECT '=== 3. 日利計算システム ===' as check_section;

-- 関数の存在確認
SELECT
    proname as function_name,
    pronargs as arg_count,
    pg_get_function_result(oid) as return_type
FROM pg_proc
WHERE proname = 'process_daily_yield_with_cycles';

-- 日利ログの最新レコード確認
SELECT
    date,
    yield_rate,
    margin_rate,
    user_rate,
    total_users,
    created_at
FROM daily_yield_log
ORDER BY date DESC
LIMIT 5;

-- 4. 月末出金・タスクシステムのチェック
SELECT '=== 4. 月末出金・タスクシステム ===' as check_section;

-- 関連関数の確認
SELECT proname, pronargs
FROM pg_proc
WHERE proname IN (
    'process_monthly_withdrawals',
    'complete_reward_task',
    'complete_withdrawals_batch'
)
ORDER BY proname;

-- monthly_withdrawalsテーブルの確認
SELECT
    COUNT(*) as total_withdrawals,
    COUNT(*) FILTER (WHERE status = 'on_hold') as on_hold_count,
    COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
    COUNT(*) FILTER (WHERE status = 'completed') as completed_count
FROM monthly_withdrawals;

-- monthly_reward_tasksテーブルの確認
SELECT
    COUNT(*) as total_tasks,
    COUNT(*) FILTER (WHERE is_completed = true) as completed_tasks,
    COUNT(*) FILTER (WHERE is_completed = false) as pending_tasks
FROM monthly_reward_tasks;

-- 5. NFT買取申請機能のチェック
SELECT '=== 5. NFT買取申請（buyback）機能 ===' as check_section;

-- 関連関数の確認
SELECT proname, pronargs
FROM pg_proc
WHERE proname LIKE '%buyback%'
ORDER BY proname;

-- buyback_requestsテーブルの確認
SELECT
    COUNT(*) as total_requests,
    COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
    COUNT(*) FILTER (WHERE status = 'approved') as approved_count,
    COUNT(*) FILTER (WHERE status = 'completed') as completed_count,
    COUNT(*) FILTER (WHERE status = 'rejected') as rejected_count
FROM buyback_requests;

-- 6. NFT自動付与システムのチェック
SELECT '=== 6. NFT自動付与システム ===' as check_section;

-- 自動NFTの確認
SELECT
    COUNT(*) as total_auto_nfts,
    COUNT(DISTINCT user_id) as users_with_auto_nft
FROM nft_master
WHERE nft_type = 'auto';

-- 自動購入レコードの確認
SELECT
    COUNT(*) as total_auto_purchases,
    COUNT(DISTINCT user_id) as users_with_auto_purchase,
    SUM(amount_usd) as total_auto_purchase_amount
FROM purchases
WHERE is_auto_purchase = true;

-- 7. affiliate_cycleテーブルの状態確認
SELECT '=== 7. アフィリエイトサイクル ===' as check_section;

SELECT
    COUNT(*) as total_users_in_cycle,
    SUM(manual_nft_count) as total_manual_nfts,
    SUM(auto_nft_count) as total_auto_nfts,
    SUM(total_nft_count) as total_all_nfts,
    SUM(cum_usdt) as total_cumulative_usdt,
    SUM(available_usdt) as total_available_usdt,
    COUNT(*) FILTER (WHERE phase = 'USDT') as usdt_phase_count,
    COUNT(*) FILTER (WHERE phase = 'HOLD') as hold_phase_count
FROM affiliate_cycle;

-- 8. 運用開始日の確認
SELECT '=== 8. 運用開始日設定 ===' as check_section;

SELECT
    COUNT(*) as total_users,
    COUNT(*) FILTER (WHERE operation_start_date IS NOT NULL) as users_with_start_date,
    COUNT(*) FILTER (WHERE operation_start_date IS NULL) as users_without_start_date,
    COUNT(*) FILTER (WHERE operation_start_date <= CURRENT_DATE) as users_in_operation,
    COUNT(*) FILTER (WHERE operation_start_date > CURRENT_DATE) as users_waiting
FROM users;

-- 9. データ整合性チェック
SELECT '=== 9. データ整合性チェック ===' as check_section;

-- nft_masterとaffiliate_cycleの整合性
WITH nft_counts AS (
    SELECT
        user_id,
        COUNT(*) FILTER (WHERE nft_type = 'manual') as manual_count,
        COUNT(*) FILTER (WHERE nft_type = 'auto') as auto_count,
        COUNT(*) as total_count
    FROM nft_master
    GROUP BY user_id
),
cycle_counts AS (
    SELECT
        user_id,
        manual_nft_count,
        auto_nft_count,
        total_nft_count
    FROM affiliate_cycle
)
SELECT
    COUNT(*) as users_with_mismatch,
    'NFTカウント不整合' as issue_type
FROM nft_counts n
FULL OUTER JOIN cycle_counts c USING (user_id)
WHERE
    COALESCE(n.manual_count, 0) != COALESCE(c.manual_nft_count, 0)
    OR COALESCE(n.auto_count, 0) != COALESCE(c.auto_nft_count, 0)
    OR COALESCE(n.total_count, 0) != COALESCE(c.total_nft_count, 0);

-- 10. 重要なVIEWの確認
SELECT '=== 10. VIEWの存在確認 ===' as check_section;

SELECT
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public'
    AND table_type = 'VIEW'
    AND table_name IN ('user_daily_profit', 'admin_purchases_view')
ORDER BY table_name;

-- 11. RLS（Row Level Security）の確認
SELECT '=== 11. RLSポリシー確認 ===' as check_section;

SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies
WHERE tablename IN (
    'users',
    'purchases',
    'nft_master',
    'buyback_requests',
    'monthly_withdrawals',
    'affiliate_cycle'
)
ORDER BY tablename, policyname;

-- 12. 最終サマリー
SELECT '=== 最終サマリー ===' as check_section;

SELECT
    '総ユーザー数' as metric,
    COUNT(*)::TEXT as value
FROM users
UNION ALL
SELECT
    '運用中ユーザー数',
    COUNT(*)::TEXT
FROM users
WHERE operation_start_date IS NOT NULL AND operation_start_date <= CURRENT_DATE
UNION ALL
SELECT
    '総NFT数',
    COUNT(*)::TEXT
FROM nft_master
UNION ALL
SELECT
    '総購入レコード数',
    COUNT(*)::TEXT
FROM purchases
UNION ALL
SELECT
    '承認済み購入数',
    COUNT(*)::TEXT
FROM purchases
WHERE admin_approved = true
UNION ALL
SELECT
    '買取申請数',
    COUNT(*)::TEXT
FROM buyback_requests
UNION ALL
SELECT
    '月末出金申請数',
    COUNT(*)::TEXT
FROM monthly_withdrawals;

SELECT '✅ 全チェック完了' as status;
