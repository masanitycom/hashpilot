-- 月末処理の実装と動作を検証するスクリプト

-- 1. 月末処理関数の存在確認
SELECT '=== 月末処理関数確認 ===' as section;
SELECT 
    proname as function_name,
    prosrc LIKE '%month%end%' as has_month_end_logic,
    prosrc LIKE '%is_month_end%' as has_month_end_parameter
FROM pg_proc 
WHERE proname IN ('process_daily_yield_with_cycles', 'execute_daily_batch')
ORDER BY proname;

-- 2. 月末フラグのテーブル構造確認
SELECT '=== テーブル構造確認 ===' as section;
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name IN ('daily_yield_log', 'user_daily_profit', 'system_logs')
AND column_name LIKE '%month%'
ORDER BY table_name, column_name;

-- 3. 月末処理のテスト実行（テストモード）
SELECT '=== 月末処理テスト実行 ===' as section;

-- テスト用の日利データを作成（月末フラグ有効）
DO $$
DECLARE
    test_date DATE := '2025-07-31';  -- 月末日でテスト
    base_yield_rate NUMERIC := 0.015;  -- 1.5%
    margin_rate NUMERIC := 30;
    month_end_bonus NUMERIC := 0.05;  -- 5%ボーナス
    expected_user_rate NUMERIC;
BEGIN
    -- 期待値計算: 1.5% × (1-30%) × 0.6 × (1+5%) = 0.6615%
    expected_user_rate := base_yield_rate * (1 - margin_rate/100) * 0.6 * (1 + month_end_bonus);
    
    RAISE NOTICE 'Testing month-end processing for date: %', test_date;
    RAISE NOTICE 'Base yield rate: %', base_yield_rate;
    RAISE NOTICE 'Expected user rate with 5%% bonus: %', expected_user_rate;
    
    -- テスト用データをクリーンアップ
    DELETE FROM user_daily_profit WHERE date = test_date;
    DELETE FROM daily_yield_log WHERE date = test_date;
    
    -- 月末処理フラグ有効でテスト実行
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'process_daily_yield_with_cycles') THEN
        PERFORM process_daily_yield_with_cycles(
            test_date,
            base_yield_rate,
            margin_rate,
            true,  -- テストモード
            true   -- 月末処理フラグ
        );
        RAISE NOTICE 'Month-end processing test executed successfully';
    ELSE
        RAISE NOTICE 'process_daily_yield_with_cycles function not found';
    END IF;
END $$;

-- 4. 月末処理結果の検証
SELECT '=== 月末処理結果検証 ===' as section;
WITH month_end_verification AS (
    SELECT 
        dyl.date,
        dyl.yield_rate,
        dyl.margin_rate,
        dyl.user_rate,
        dyl.is_month_end,
        -- 期待値計算
        dyl.yield_rate * (1 - dyl.margin_rate/100) * 0.6 as normal_user_rate,
        dyl.yield_rate * (1 - dyl.margin_rate/100) * 0.6 * 1.05 as month_end_user_rate,
        -- どちらの計算が適用されているかチェック
        CASE 
            WHEN dyl.is_month_end AND abs(dyl.user_rate - (dyl.yield_rate * (1 - dyl.margin_rate/100) * 0.6 * 1.05)) < 0.000001
            THEN 'Month-end bonus applied correctly'
            WHEN NOT dyl.is_month_end AND abs(dyl.user_rate - (dyl.yield_rate * (1 - dyl.margin_rate/100) * 0.6)) < 0.000001
            THEN 'Normal rate applied correctly'
            ELSE 'Rate calculation error'
        END as rate_verification
    FROM daily_yield_log dyl
    WHERE dyl.date = '2025-07-31'
)
SELECT 
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    normal_user_rate,
    month_end_user_rate,
    rate_verification,
    CASE 
        WHEN is_month_end 
        THEN ((user_rate / normal_user_rate - 1) * 100)::NUMERIC(5,2)
        ELSE 0 
    END as actual_bonus_percentage
FROM month_end_verification;

-- 5. ユーザー利益への月末ボーナス適用確認
SELECT '=== ユーザー利益月末ボーナス確認 ===' as section;
SELECT 
    u.user_id,
    u.email,
    ac.total_nft_count,
    udp.base_amount,
    udp.personal_profit,
    udp.yield_rate,
    udp.user_rate,
    -- 通常時の期待利益
    (ac.total_nft_count * 1000 * (udp.yield_rate * 0.7 * 0.6)) as normal_expected_profit,
    -- 月末ボーナス込みの期待利益
    (ac.total_nft_count * 1000 * (udp.yield_rate * 0.7 * 0.6 * 1.05)) as month_end_expected_profit,
    -- 実際のボーナス率
    CASE 
        WHEN ac.total_nft_count > 0 AND udp.yield_rate > 0
        THEN ((udp.personal_profit / (ac.total_nft_count * 1000 * udp.yield_rate * 0.7 * 0.6)) - 1) * 100
        ELSE 0 
    END as actual_bonus_percentage
FROM users u
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE udp.date = '2025-07-31'
AND ac.total_nft_count > 0
ORDER BY u.total_purchases DESC
LIMIT 10;

-- 6. 月末処理の自動化確認
SELECT '=== 月末自動処理確認 ===' as section;
SELECT 
    'Month-end automation check' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.routines 
            WHERE routine_name = 'execute_daily_batch'
            AND routine_definition LIKE '%month%end%'
        )
        THEN 'Month-end logic exists in batch function'
        ELSE 'Month-end logic not found in batch function'
    END as batch_integration,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = 'system_settings'
        )
        THEN 'System settings table exists for configuration'
        ELSE 'System settings table missing'
    END as configuration_status;

-- 7. 月末処理ログの確認
SELECT '=== 月末処理ログ確認 ===' as section;
SELECT 
    log_type,
    operation,
    message,
    details,
    created_at
FROM system_logs 
WHERE (message LIKE '%month%end%' OR details::text LIKE '%month%end%')
AND created_at >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY created_at DESC
LIMIT 10;

-- 8. 月末処理の実装ステータス確認
SELECT '=== 月末処理実装ステータス ===' as section;
SELECT 
    'Month-end processing implementation status' as description,
    CASE 
        WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'daily_yield_log' AND column_name = 'is_month_end')
        THEN '✅ is_month_end flag implemented'
        ELSE '❌ is_month_end flag missing'
    END as flag_status,
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'process_daily_yield_with_cycles' AND prosrc LIKE '%is_month_end%')
        THEN '✅ Month-end logic in processing function'
        ELSE '❌ Month-end logic missing in processing function'
    END as function_status,
    CASE 
        WHEN EXISTS (SELECT 1 FROM daily_yield_log WHERE is_month_end = true)
        THEN '✅ Month-end processing has been executed'
        ELSE '⚠️  Month-end processing not yet executed'
    END as execution_status;

-- クリーンアップ（テストデータ削除）
DELETE FROM user_daily_profit WHERE date = '2025-07-31';
DELETE FROM daily_yield_log WHERE date = '2025-07-31';

SELECT 'Month-end processing verification completed' as message;