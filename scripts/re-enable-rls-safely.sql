-- RLS安全再有効化スクリプト
-- 2025-07-11の緊急無効化後の正常化対応
-- 段階的に再有効化して影響を最小化

-- ========================================
-- 1. 現在の状態を再確認
-- ========================================
SELECT 
    tablename,
    rowsecurity as rls_enabled,
    CASE WHEN rowsecurity THEN '🔒 RLS有効' ELSE '⚠️ RLS無効' END as status
FROM pg_tables 
WHERE tablename IN ('buyback_requests', 'affiliate_cycle', 'user_daily_profit', 'system_logs')
    AND schemaname = 'public'
ORDER BY tablename;

-- ========================================
-- 2. 買い取り関連の関数を確認（SECURITY DEFINER設定）
-- ========================================
SELECT 
    p.proname AS function_name,
    p.prosecdef AS security_definer,
    CASE WHEN p.prosecdef THEN '✅ SECURITY DEFINER' ELSE '❌ 通常実行' END as security_type
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
    AND p.proname IN ('create_buyback_request', 'process_buyback_request', 'get_buyback_requests')
ORDER BY p.proname;

-- ========================================
-- 3. 段階的なRLS再有効化
-- ========================================

-- Step 1: system_logsから開始（影響が最小）
BEGIN;
    -- RLS有効化
    ALTER TABLE system_logs ENABLE ROW LEVEL SECURITY;
    
    -- ログ記録
    INSERT INTO system_logs (
        log_type,
        operation,
        user_id,
        message,
        details,
        created_at
    ) VALUES (
        'INFO',
        'rls_re_enable_step1',
        NULL,
        'system_logsテーブルのRLSを再有効化しました',
        jsonb_build_object(
            'table', 'system_logs',
            'step', 1,
            'reason', '段階的RLS正常化'
        ),
        NOW()
    );
COMMIT;

-- Step 2: user_daily_profit（読み取り専用に近い）
BEGIN;
    -- RLS有効化
    ALTER TABLE user_daily_profit ENABLE ROW LEVEL SECURITY;
    
    -- ログ記録
    INSERT INTO system_logs (
        log_type,
        operation,
        user_id,
        message,
        details,
        created_at
    ) VALUES (
        'INFO',
        'rls_re_enable_step2',
        NULL,
        'user_daily_profitテーブルのRLSを再有効化しました',
        jsonb_build_object(
            'table', 'user_daily_profit',
            'step', 2,
            'reason', '段階的RLS正常化'
        ),
        NOW()
    );
COMMIT;

-- Step 3: affiliate_cycle（重要度中）
BEGIN;
    -- RLS有効化
    ALTER TABLE affiliate_cycle ENABLE ROW LEVEL SECURITY;
    
    -- ログ記録
    INSERT INTO system_logs (
        log_type,
        operation,
        user_id,
        message,
        details,
        created_at
    ) VALUES (
        'INFO',
        'rls_re_enable_step3',
        NULL,
        'affiliate_cycleテーブルのRLSを再有効化しました',
        jsonb_build_object(
            'table', 'affiliate_cycle',
            'step', 3,
            'reason', '段階的RLS正常化'
        ),
        NOW()
    );
COMMIT;

-- Step 4: buyback_requests（最も重要）
BEGIN;
    -- RLS有効化
    ALTER TABLE buyback_requests ENABLE ROW LEVEL SECURITY;
    
    -- ログ記録
    INSERT INTO system_logs (
        log_type,
        operation,
        user_id,
        message,
        details,
        created_at
    ) VALUES (
        'SUCCESS',
        'rls_re_enable_complete',
        NULL,
        'すべてのテーブルのRLSを再有効化しました',
        jsonb_build_object(
            'affected_tables', ARRAY['buyback_requests', 'affiliate_cycle', 'user_daily_profit', 'system_logs'],
            'previous_disable_date', '2025-07-11T15:29:59.458817+00:00',
            're_enable_date', NOW(),
            'admin_action', true
        ),
        NOW()
    );
COMMIT;

-- ========================================
-- 4. 再有効化後の状態確認
-- ========================================
SELECT 
    tablename,
    rowsecurity as rls_enabled,
    CASE WHEN rowsecurity THEN '🔒 RLS有効' ELSE '⚠️ RLS無効' END as final_status
FROM pg_tables 
WHERE tablename IN ('buyback_requests', 'affiliate_cycle', 'user_daily_profit', 'system_logs')
    AND schemaname = 'public'
ORDER BY tablename;

-- ========================================
-- 5. テスト用クエリ（動作確認）
-- ========================================
-- 各テーブルへの基本的なSELECTクエリをテスト
-- エラーが発生しないことを確認

-- system_logsのテスト
SELECT COUNT(*) as log_count FROM system_logs WHERE created_at >= CURRENT_DATE - INTERVAL '1 day';

-- user_daily_profitのテスト  
SELECT COUNT(*) as profit_count FROM user_daily_profit WHERE date >= CURRENT_DATE - INTERVAL '7 days';

-- affiliate_cycleのテスト
SELECT COUNT(*) as cycle_count FROM affiliate_cycle WHERE cycle_start_date IS NOT NULL;

-- buyback_requestsのテスト
SELECT COUNT(*) as buyback_count FROM buyback_requests WHERE created_at >= CURRENT_DATE - INTERVAL '30 days';

-- ========================================
-- 6. エラーが発生した場合の緊急ロールバック
-- ========================================
-- ※ 以下はエラー発生時のみ実行
/*
-- すべてのRLSを再度無効化（緊急時のみ）
ALTER TABLE buyback_requests DISABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_cycle DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_daily_profit DISABLE ROW LEVEL SECURITY;
ALTER TABLE system_logs DISABLE ROW LEVEL SECURITY;

-- エラーログ記録
INSERT INTO system_logs (
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
) VALUES (
    'ERROR',
    'rls_re_enable_rollback',
    NULL,
    'RLS再有効化でエラーが発生したため、ロールバックしました',
    jsonb_build_object(
        'reason', '再有効化後にエラーが発生',
        'action', '全テーブルのRLS再無効化',
        'next_step', 'ポリシーの見直しが必要'
    ),
    NOW()
);
*/