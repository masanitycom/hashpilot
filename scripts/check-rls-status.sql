-- RLS状態確認と再有効化スクリプト
-- 2025-07-11の緊急無効化対応

-- 1. 現在のRLS状態確認
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled,
    CASE WHEN rowsecurity THEN '🔒 RLS有効' ELSE '⚠️ RLS無効' END as security_status
FROM pg_tables 
WHERE tablename IN ('buyback_requests', 'affiliate_cycle', 'user_daily_profit', 'system_logs')
    AND schemaname = 'public'
ORDER BY tablename;

-- 2. 各テーブルの詳細なRLSポリシー確認
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename IN ('buyback_requests', 'affiliate_cycle', 'user_daily_profit', 'system_logs')
    AND schemaname = 'public'
ORDER BY tablename, policyname;

-- 3. RLS再有効化（必要に応じて実行）
/*
-- buyback_requests テーブルのRLS再有効化
ALTER TABLE buyback_requests ENABLE ROW LEVEL SECURITY;

-- affiliate_cycle テーブルのRLS再有効化  
ALTER TABLE affiliate_cycle ENABLE ROW LEVEL SECURITY;

-- user_daily_profit テーブルのRLS再有効化
ALTER TABLE user_daily_profit ENABLE ROW LEVEL SECURITY;

-- system_logs テーブルのRLS再有効化
ALTER TABLE system_logs ENABLE ROW LEVEL SECURITY;
*/

-- 4. 系統ログに再有効化を記録（実際に再有効化した場合）
/*
INSERT INTO system_logs (
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
) VALUES (
    'SUCCESS',
    'rls_re_enable',
    NULL,
    'RLSセキュリティを再有効化しました',
    jsonb_build_object(
        'reason', '緊急無効化後の正常化',
        'affected_tables', ARRAY['buyback_requests', 'affiliate_cycle', 'user_daily_profit', 'system_logs'],
        'previous_disable_date', '2025-07-11T15:29:59.458817+00:00',
        'admin_action', true
    ),
    NOW()
);
*/

-- 5. 現在のセキュリティ状況サマリー
SELECT 
    COUNT(*) as total_tables,
    COUNT(CASE WHEN rowsecurity THEN 1 END) as rls_enabled_count,
    COUNT(CASE WHEN NOT rowsecurity THEN 1 END) as rls_disabled_count,
    ROUND(
        COUNT(CASE WHEN rowsecurity THEN 1 END) * 100.0 / COUNT(*), 
        1
    ) as rls_enabled_percentage
FROM pg_tables 
WHERE tablename IN ('buyback_requests', 'affiliate_cycle', 'user_daily_profit', 'system_logs')
    AND schemaname = 'public';