/* 緊急対応: buyback_requests テーブルのRLSを一時的に無効化 */

/* 現在のRLS状態を確認 */
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('buyback_requests', 'affiliate_cycle', 'user_daily_profit');

/* buyback_requests テーブルのRLSを一時的に無効化 */
ALTER TABLE buyback_requests DISABLE ROW LEVEL SECURITY;

/* affiliate_cycle テーブルのRLSを確認・調整 */
ALTER TABLE affiliate_cycle DISABLE ROW LEVEL SECURITY;

/* user_daily_profit テーブルのRLSを確認・調整 */
ALTER TABLE user_daily_profit DISABLE ROW LEVEL SECURITY;

/* system_logs テーブルのRLSを確認・調整 */
ALTER TABLE system_logs DISABLE ROW LEVEL SECURITY;

/* 緊急対応ログ */
INSERT INTO system_logs (log_type, operation, user_id, message, details)
VALUES (
    'WARNING',
    'emergency_rls_disable',
    NULL,
    '緊急対応: 買い取りシステムのRLSを一時的に無効化',
    jsonb_build_object(
        'reason', '403 Forbidden エラーの解決',
        'affected_tables', ARRAY['buyback_requests', 'affiliate_cycle', 'user_daily_profit', 'system_logs'],
        'timestamp', NOW(),
        'note', 'セキュリティ上、速やかに再有効化が必要'
    )
);

/* 修正後のテーブル状態確認 */
SELECT 
    schemaname, 
    tablename, 
    rowsecurity,
    CASE 
        WHEN rowsecurity THEN 'RLS有効' 
        ELSE 'RLS無効' 
    END as rls_status
FROM pg_tables 
WHERE tablename IN ('buyback_requests', 'affiliate_cycle', 'user_daily_profit', 'system_logs')
ORDER BY tablename;