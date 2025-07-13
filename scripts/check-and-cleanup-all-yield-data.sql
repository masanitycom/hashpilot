-- 過去の日利データ確認と削除
-- 実際の運用開始前の全データクリーンアップ

-- ========================================
-- 1. 現在の全日利データを確認
-- ========================================
SELECT 
    id,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at,
    CASE 
        WHEN margin_rate > 100 THEN '🔴 異常値'
        WHEN date = CURRENT_DATE THEN '📅 今日'
        WHEN date = CURRENT_DATE - INTERVAL '1 day' THEN '📅 昨日'
        ELSE '📊 過去データ'
    END as status
FROM daily_yield_log 
ORDER BY date DESC, created_at DESC;

-- ========================================
-- 2. 対応する日利配布データを確認
-- ========================================
SELECT 
    date,
    COUNT(*) as user_count,
    SUM(daily_profit) as total_profit,
    AVG(daily_profit) as avg_profit,
    MIN(daily_profit) as min_profit,
    MAX(daily_profit) as max_profit,
    CASE 
        WHEN date = CURRENT_DATE THEN '📅 今日'
        WHEN date = CURRENT_DATE - INTERVAL '1 day' THEN '📅 昨日'
        ELSE '📊 過去データ'
    END as status
FROM user_daily_profit 
GROUP BY date 
ORDER BY date DESC;

-- ========================================
-- 3. 日利計算の妥当性チェック
-- ========================================
SELECT 
    udp.date,
    udp.user_id,
    udp.daily_profit,
    udp.yield_rate,
    udp.user_rate,
    udp.base_amount,
    -- 再計算: base_amount × user_rate
    ROUND(udp.base_amount * udp.user_rate, 4) as recalculated_profit,
    -- 差異チェック
    ROUND(udp.daily_profit - (udp.base_amount * udp.user_rate), 4) as difference,
    CASE 
        WHEN ABS(udp.daily_profit - (udp.base_amount * udp.user_rate)) < 0.01 THEN '✅ 正確'
        ELSE '❌ 計算ミス'
    END as calculation_status
FROM user_daily_profit udp
WHERE udp.date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY udp.date DESC, ABS(udp.daily_profit - (udp.base_amount * udp.user_rate)) DESC
LIMIT 20;

-- ========================================
-- 4. 実運用前の全データ削除確認
-- ========================================

-- 削除前のデータ量確認
SELECT 
    'BEFORE_DELETE' as phase,
    (SELECT COUNT(*) FROM daily_yield_log) as yield_records,
    (SELECT COUNT(*) FROM user_daily_profit) as profit_records,
    (SELECT COUNT(DISTINCT date) FROM daily_yield_log) as affected_dates;

-- ========================================
-- 5. 全日利データを削除（実運用前クリーンアップ）
-- ========================================

-- user_daily_profitから全削除
DELETE FROM user_daily_profit;

-- daily_yield_logから全削除  
DELETE FROM daily_yield_log;

-- 削除後の確認
SELECT 
    'AFTER_DELETE' as phase,
    (SELECT COUNT(*) FROM daily_yield_log) as remaining_yield_records,
    (SELECT COUNT(*) FROM user_daily_profit) as remaining_profit_records,
    CASE 
        WHEN (SELECT COUNT(*) FROM daily_yield_log) = 0 
         AND (SELECT COUNT(*) FROM user_daily_profit) = 0 
        THEN '✅ 完全削除完了'
        ELSE '❌ データが残存'
    END as cleanup_status;

-- ========================================
-- 6. 削除ログを記録
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
    'pre_production_data_cleanup',
    NULL,
    '実運用開始前に全ての日利テストデータを削除しました',
    jsonb_build_object(
        'reason', '実運用開始前のデータクリーンアップ',
        'deleted_tables', ARRAY['daily_yield_log', 'user_daily_profit'],
        'cleanup_date', CURRENT_DATE,
        'note', '計算確認後の全データ削除'
    ),
    NOW()
);

-- ========================================
-- 7. システム準備完了確認
-- ========================================
SELECT 
    'SYSTEM_READY' as status,
    '🎉 実運用準備完了' as message,
    '新規日利設定が可能です' as next_action,
    CURRENT_DATE as ready_date;

-- ========================================
-- 8. 制約・関数の最終確認
-- ========================================

-- 日利設定関数の確認
SELECT 
    'FUNCTIONS' as check_type,
    COUNT(*) as function_count,
    ARRAY_AGG(p.proname) as available_functions
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
    AND p.proname IN (
        'process_daily_yield_with_cycles',
        'admin_cancel_yield_posting'
    );

-- テーブル制約の確認
SELECT 
    'CONSTRAINTS' as check_type,
    constraint_name,
    constraint_type
FROM information_schema.table_constraints 
WHERE table_name = 'daily_yield_log' 
    AND constraint_type = 'UNIQUE';

-- RLS状態の確認
SELECT 
    'RLS_STATUS' as check_type,
    tablename,
    rowsecurity as rls_enabled,
    CASE WHEN rowsecurity THEN '🔒 セキュア' ELSE '⚠️ 無効' END as security_status
FROM pg_tables 
WHERE tablename IN ('daily_yield_log', 'user_daily_profit')
    AND schemaname = 'public';