-- ========================================
-- 最近の変更による影響確認スクリプト
-- ========================================

SELECT '=== 1. 新規カラムの確認 ===' as section;

-- cycle_number_at_purchase カラムが追加されたか
SELECT
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'purchases'
  AND column_name = 'cycle_number_at_purchase';

SELECT '=== 2. 新規関数の確認 ===' as section;

-- complete_withdrawal 関数
SELECT
    proname as function_name,
    pronargs as num_args
FROM pg_proc
WHERE proname IN ('complete_withdrawal', 'complete_withdrawals_batch')
ORDER BY proname;

-- get_auto_purchase_history 関数
SELECT
    proname as function_name,
    pronargs as num_args
FROM pg_proc
WHERE proname = 'get_auto_purchase_history';

SELECT '=== 3. データ整合性チェック ===' as section;

-- 自動購入レコードのサイクル番号
SELECT
    COUNT(*) as total_auto_purchases,
    COUNT(cycle_number_at_purchase) as with_cycle_number,
    COUNT(*) - COUNT(cycle_number_at_purchase) as without_cycle_number
FROM purchases
WHERE is_auto_purchase = true;

-- サイクル番号の範囲
SELECT
    MIN(cycle_number_at_purchase) as min_cycle,
    MAX(cycle_number_at_purchase) as max_cycle,
    COUNT(DISTINCT cycle_number_at_purchase) as unique_cycles
FROM purchases
WHERE is_auto_purchase = true
  AND cycle_number_at_purchase IS NOT NULL;

SELECT '=== 4. 出金データの確認 ===' as section;

-- monthly_withdrawals の状態
SELECT
    status,
    COUNT(*) as count,
    SUM(total_amount) as total_amount
FROM monthly_withdrawals
GROUP BY status
ORDER BY status;

-- タスク完了状況
SELECT
    task_completed,
    COUNT(*) as count
FROM monthly_withdrawals
GROUP BY task_completed;

SELECT '=== 5. affiliate_cycle の整合性 ===' as section;

-- available_usdt がマイナスになっていないか
SELECT
    COUNT(*) as negative_balance_users
FROM affiliate_cycle
WHERE available_usdt < 0;

-- cum_usdt がマイナスになっていないか
SELECT
    COUNT(*) as negative_cum_users
FROM affiliate_cycle
WHERE cum_usdt < 0;

SELECT '=== 6. 7E0A1E ユーザーの詳細確認 ===' as section;

-- 7E0A1Eの自動購入履歴
SELECT
    id,
    created_at::date as purchase_date,
    nft_quantity,
    amount_usd,
    cycle_number_at_purchase
FROM purchases
WHERE user_id = '7E0A1E'
  AND is_auto_purchase = true
ORDER BY created_at;

-- 7E0A1Eの現在の状態
SELECT
    user_id,
    cycle_number,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    available_usdt,
    cum_usdt
FROM affiliate_cycle
WHERE user_id = '7E0A1E';

SELECT '=== 7. get_auto_purchase_history 関数のテスト ===' as section;

-- 関数を実際に実行してエラーがないか確認
SELECT
    purchase_id,
    purchase_date::date,
    nft_quantity,
    amount_usd,
    cycle_number
FROM get_auto_purchase_history('7E0A1E', 5);

SELECT '=== 8. 変更された関数のバージョン確認 ===' as section;

-- process_daily_yield_with_cycles 関数の存在確認
SELECT
    proname as function_name,
    pronargs as num_args
FROM pg_proc
WHERE proname = 'process_daily_yield_with_cycles';

SELECT '=== 完了 ===' as section;
SELECT '全ての確認が完了しました。' as message;
SELECT 'エラーや警告がなければ、システムは正常です。' as message;
