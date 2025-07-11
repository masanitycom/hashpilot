-- システムログ関連のテーブルと関数を作成

-- 1. system_logsテーブルの作成
CREATE TABLE IF NOT EXISTS system_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    log_type TEXT NOT NULL,
    operation TEXT,
    user_id TEXT,
    details JSONB,
    message TEXT,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- インデックスの作成
CREATE INDEX IF NOT EXISTS idx_system_logs_created_at ON system_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_system_logs_log_type ON system_logs(log_type);
CREATE INDEX IF NOT EXISTS idx_system_logs_operation ON system_logs(operation);
CREATE INDEX IF NOT EXISTS idx_system_logs_user_id ON system_logs(user_id);

-- 2. get_system_logs関数の作成
CREATE OR REPLACE FUNCTION get_system_logs(
    p_limit INTEGER DEFAULT 100,
    p_log_type TEXT DEFAULT NULL,
    p_operation TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    log_type TEXT,
    operation TEXT,
    user_id TEXT,
    details JSONB,
    message TEXT,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sl.id,
        sl.log_type,
        sl.operation,
        sl.user_id,
        sl.details,
        sl.message,
        sl.ip_address,
        sl.user_agent,
        sl.created_at
    FROM system_logs sl
    WHERE 
        (p_log_type IS NULL OR sl.log_type = p_log_type)
        AND (p_operation IS NULL OR sl.operation = p_operation)
    ORDER BY sl.created_at DESC
    LIMIT p_limit;
END;
$$;

-- 3. system_health_check関数の作成
CREATE OR REPLACE FUNCTION system_health_check()
RETURNS TABLE (
    component TEXT,
    status TEXT,
    message TEXT,
    last_check TIMESTAMP WITH TIME ZONE,
    details JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_count INTEGER;
    v_active_user_count INTEGER;
    v_total_investment NUMERIC;
    v_db_size TEXT;
    v_recent_logs INTEGER;
    v_recent_errors INTEGER;
BEGIN
    -- ユーザー統計
    SELECT COUNT(*), COUNT(*) FILTER (WHERE is_active = true)
    INTO v_user_count, v_active_user_count
    FROM users;
    
    -- 投資総額
    SELECT COALESCE(SUM(amount_usd::NUMERIC), 0)
    INTO v_total_investment
    FROM purchases
    WHERE admin_approved = true;
    
    -- データベースサイズ
    SELECT pg_size_pretty(pg_database_size(current_database()))
    INTO v_db_size;
    
    -- 最近のログ数
    SELECT COUNT(*)
    INTO v_recent_logs
    FROM system_logs
    WHERE created_at > NOW() - INTERVAL '24 hours';
    
    -- 最近のエラー数
    SELECT COUNT(*)
    INTO v_recent_errors
    FROM system_logs
    WHERE created_at > NOW() - INTERVAL '24 hours'
    AND log_type IN ('error', 'critical');
    
    -- データベース接続
    RETURN QUERY
    SELECT 
        'database'::TEXT,
        'healthy'::TEXT,
        'データベース接続正常'::TEXT,
        NOW(),
        jsonb_build_object(
            'size', v_db_size,
            'version', version()
        );
    
    -- ユーザー統計
    RETURN QUERY
    SELECT 
        'users'::TEXT,
        'healthy'::TEXT,
        format('総ユーザー数: %s / アクティブ: %s', v_user_count, v_active_user_count)::TEXT,
        NOW(),
        jsonb_build_object(
            'total', v_user_count,
            'active', v_active_user_count
        );
    
    -- 投資統計
    RETURN QUERY
    SELECT 
        'investments'::TEXT,
        'healthy'::TEXT,
        format('総投資額: $%s', TO_CHAR(v_total_investment, 'FM999,999,990.00'))::TEXT,
        NOW(),
        jsonb_build_object(
            'total_amount', v_total_investment
        );
    
    -- ログシステム
    RETURN QUERY
    SELECT 
        'logging'::TEXT,
        CASE 
            WHEN v_recent_errors > 10 THEN 'warning'
            ELSE 'healthy'
        END::TEXT,
        format('24時間以内: %sログ / %sエラー', v_recent_logs, v_recent_errors)::TEXT,
        NOW(),
        jsonb_build_object(
            'recent_logs', v_recent_logs,
            'recent_errors', v_recent_errors
        );
    
    -- NFTサイクル
    RETURN QUERY
    SELECT 
        'nft_cycles'::TEXT,
        'healthy'::TEXT,
        'NFTサイクル処理正常'::TEXT,
        NOW(),
        (SELECT jsonb_build_object(
            'active_cycles', COUNT(*),
            'total_nft', SUM(total_nft_count)
        ) FROM affiliate_cycle WHERE total_nft_count > 0);
    
END;
$$;

-- 4. ログ記録用のヘルパー関数
CREATE OR REPLACE FUNCTION log_system_event(
    p_log_type TEXT,
    p_operation TEXT,
    p_message TEXT,
    p_user_id TEXT DEFAULT NULL,
    p_details JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO system_logs (
        log_type,
        operation,
        user_id,
        message,
        details,
        created_at
    ) VALUES (
        p_log_type,
        p_operation,
        p_user_id,
        p_message,
        p_details,
        NOW()
    ) RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$;

-- 5. サンプルログの追加（テスト用）
INSERT INTO system_logs (log_type, operation, message, details) VALUES
('info', 'system_start', 'システムが正常に起動しました', '{"version": "1.0.0"}'::jsonb),
('info', 'monthly_withdrawal', '月末自動出金処理を実行しました', '{"processed": 0, "total_amount": 0}'::jsonb),
('info', 'user_login', 'ユーザーがログインしました', '{"method": "email"}'::jsonb)
ON CONFLICT DO NOTHING;

-- 6. RLSポリシー
ALTER TABLE system_logs ENABLE ROW LEVEL SECURITY;

-- 管理者のみアクセス可能
CREATE POLICY "admin_access_system_logs" ON system_logs
FOR ALL
TO public
USING (
    EXISTS (
        SELECT 1 FROM admins 
        WHERE email IN (
            SELECT email FROM auth.users WHERE id = auth.uid()
        )
        AND is_active = true
    )
);

-- アクセス権限の付与
GRANT EXECUTE ON FUNCTION get_system_logs TO anon, authenticated;
GRANT EXECUTE ON FUNCTION system_health_check TO anon, authenticated;
GRANT EXECUTE ON FUNCTION log_system_event TO authenticated;