-- 自動バッチ処理の設定
-- Supabase Edge Functions用のデータベース関数とスケジューリング設定

-- 1. 日次バッチ処理実行関数
CREATE OR REPLACE FUNCTION execute_daily_batch(
    p_date DATE DEFAULT CURRENT_DATE,
    p_default_yield_rate NUMERIC DEFAULT 0.015, -- 1.5%
    p_default_margin_rate NUMERIC DEFAULT 30    -- 30%
)
RETURNS TABLE(
    batch_id UUID,
    status TEXT,
    total_users INTEGER,
    total_profit NUMERIC,
    auto_nft_purchases INTEGER,
    execution_time_ms NUMERIC,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_batch_id UUID;
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_result RECORD;
    v_last_yield_rate NUMERIC;
    v_last_margin_rate NUMERIC;
    v_execution_time_ms NUMERIC;
BEGIN
    v_start_time := NOW();
    v_batch_id := gen_random_uuid();
    
    -- 最後の利率設定を取得
    SELECT yield_rate, margin_rate 
    FROM daily_yield_log 
    ORDER BY date DESC 
    LIMIT 1
    INTO v_last_yield_rate, v_last_margin_rate;
    
    -- デフォルト値を使用
    v_last_yield_rate := COALESCE(v_last_yield_rate, p_default_yield_rate);
    v_last_margin_rate := COALESCE(v_last_margin_rate, p_default_margin_rate);
    
    -- バッチ開始ログ
    PERFORM log_system_event(
        'INFO',
        'DAILY_BATCH',
        NULL,
        FORMAT('自動日次バッチ開始: 日付=%s, 利率=%s%%, マージン=%s%%', 
               p_date, v_last_yield_rate * 100, v_last_margin_rate),
        jsonb_build_object(
            'batch_id', v_batch_id,
            'date', p_date,
            'yield_rate', v_last_yield_rate,
            'margin_rate', v_last_margin_rate
        )
    );
    
    -- 日利処理実行
    SELECT * FROM process_daily_yield_with_cycles(
        p_date, 
        v_last_yield_rate, 
        v_last_margin_rate, 
        false -- 本番モード
    ) INTO v_result;
    
    v_end_time := NOW();
    v_execution_time_ms := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000;
    
    -- バッチ完了ログ
    PERFORM log_system_event(
        CASE WHEN v_result.status = 'SUCCESS' THEN 'SUCCESS' ELSE 'ERROR' END,
        'DAILY_BATCH',
        NULL,
        FORMAT('自動日次バッチ完了: %s (%s)', v_result.status, v_result.message),
        jsonb_build_object(
            'batch_id', v_batch_id,
            'execution_time_ms', v_execution_time_ms,
            'result', row_to_json(v_result)
        )
    );
    
    -- 結果を返す
    RETURN QUERY SELECT 
        v_batch_id,
        v_result.status,
        v_result.total_users,
        v_result.total_user_profit,
        v_result.auto_nft_purchases,
        v_execution_time_ms,
        v_result.message;
    
EXCEPTION WHEN OTHERS THEN
    v_end_time := NOW();
    v_execution_time_ms := EXTRACT(EPOCH FROM (v_end_time - v_start_time)) * 1000;
    
    -- エラーログ
    PERFORM log_system_event(
        'ERROR',
        'DAILY_BATCH',
        NULL,
        FORMAT('自動日次バッチエラー: %s', SQLERRM),
        jsonb_build_object(
            'batch_id', v_batch_id,
            'execution_time_ms', v_execution_time_ms,
            'error_code', SQLSTATE
        )
    );
    
    RETURN QUERY SELECT 
        v_batch_id,
        'ERROR'::TEXT,
        0::INTEGER,
        0::NUMERIC,
        0::INTEGER,
        v_execution_time_ms,
        FORMAT('バッチ処理エラー: %s', SQLERRM)::TEXT;
END;
$$;

-- 2. バッチ実行履歴テーブル
CREATE TABLE IF NOT EXISTS batch_execution_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    batch_type VARCHAR(50) NOT NULL, -- 'DAILY_YIELD', 'MONTHLY_REWARD', etc.
    execution_date DATE NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'running', -- 'running', 'success', 'error'
    total_users INTEGER,
    total_profit NUMERIC,
    auto_nft_purchases INTEGER,
    execution_time_ms NUMERIC,
    error_message TEXT,
    details JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- 3. バッチ実行記録関数
CREATE OR REPLACE FUNCTION record_batch_execution(
    p_batch_type TEXT,
    p_execution_date DATE,
    p_status TEXT,
    p_total_users INTEGER DEFAULT NULL,
    p_total_profit NUMERIC DEFAULT NULL,
    p_auto_nft_purchases INTEGER DEFAULT NULL,
    p_execution_time_ms NUMERIC DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL,
    p_details JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_batch_id UUID;
BEGIN
    INSERT INTO batch_execution_history (
        batch_type, execution_date, start_time, end_time, status,
        total_users, total_profit, auto_nft_purchases, execution_time_ms,
        error_message, details, created_at, updated_at
    )
    VALUES (
        p_batch_type, p_execution_date, NOW(), 
        CASE WHEN p_status != 'running' THEN NOW() ELSE NULL END,
        p_status, p_total_users, p_total_profit, p_auto_nft_purchases,
        p_execution_time_ms, p_error_message, p_details, NOW(), NOW()
    )
    RETURNING id INTO v_batch_id;
    
    RETURN v_batch_id;
END;
$$;

-- 4. システム健康チェック関数
CREATE OR REPLACE FUNCTION system_health_check()
RETURNS TABLE(
    check_name TEXT,
    status TEXT,
    value TEXT,
    details JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- データベース接続チェック
    RETURN QUERY SELECT 
        'database_connection'::TEXT,
        'healthy'::TEXT,
        'connected'::TEXT,
        jsonb_build_object('timestamp', NOW());
    
    -- ユーザー数チェック
    RETURN QUERY SELECT 
        'total_users'::TEXT,
        'healthy'::TEXT,
        (SELECT COUNT(*)::TEXT FROM users),
        jsonb_build_object('active_users', (SELECT COUNT(*) FROM users WHERE is_active = true));
    
    -- 保留中の出金申請チェック
    RETURN QUERY SELECT 
        'pending_withdrawals'::TEXT,
        CASE WHEN COUNT(*) > 10 THEN 'warning' ELSE 'healthy' END,
        COUNT(*)::TEXT,
        jsonb_build_object('total_amount', COALESCE(SUM(amount), 0))
    FROM withdrawal_requests 
    WHERE status = 'pending';
    
    -- 最後のバッチ実行チェック
    RETURN QUERY SELECT 
        'last_batch_execution'::TEXT,
        CASE 
            WHEN MAX(execution_date) < CURRENT_DATE - INTERVAL '2 days' THEN 'error'
            WHEN MAX(execution_date) < CURRENT_DATE - INTERVAL '1 day' THEN 'warning'
            ELSE 'healthy'
        END,
        COALESCE(MAX(execution_date)::TEXT, 'never'),
        jsonb_build_object(
            'last_status', (SELECT status FROM batch_execution_history WHERE batch_type = 'DAILY_YIELD' ORDER BY execution_date DESC LIMIT 1),
            'days_since_last', EXTRACT(DAYS FROM (CURRENT_DATE - COALESCE(MAX(execution_date), CURRENT_DATE - INTERVAL '999 days')))
        )
    FROM batch_execution_history 
    WHERE batch_type = 'DAILY_YIELD';
    
    -- エラーログチェック（過去24時間）
    RETURN QUERY SELECT 
        'recent_errors'::TEXT,
        CASE WHEN COUNT(*) > 5 THEN 'error' WHEN COUNT(*) > 0 THEN 'warning' ELSE 'healthy' END,
        COUNT(*)::TEXT,
        jsonb_build_object('error_count', COUNT(*))
    FROM system_logs 
    WHERE log_type = 'ERROR' AND created_at > NOW() - INTERVAL '24 hours';
END;
$$;

-- 5. 月次報酬計算関数（将来の実装用）
CREATE OR REPLACE FUNCTION calculate_monthly_rewards(
    p_year INTEGER,
    p_month INTEGER
)
RETURNS TABLE(
    user_id TEXT,
    total_referral_profit NUMERIC,
    level1_profit NUMERIC,
    level2_profit NUMERIC,
    level3_profit NUMERIC,
    reward_amount NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- 将来の実装: 月次報酬の計算
    -- 現在はプレースホルダー
    
    PERFORM log_system_event(
        'INFO',
        'MONTHLY_REWARD',
        NULL,
        FORMAT('月次報酬計算開始: %s年%s月', p_year, p_month),
        jsonb_build_object('year', p_year, 'month', p_month)
    );
    
    RETURN;
END;
$$;

-- 6. 実行権限付与
GRANT EXECUTE ON FUNCTION execute_daily_batch(DATE, NUMERIC, NUMERIC) TO anon;
GRANT EXECUTE ON FUNCTION execute_daily_batch(DATE, NUMERIC, NUMERIC) TO authenticated;
GRANT EXECUTE ON FUNCTION record_batch_execution(TEXT, DATE, TEXT, INTEGER, NUMERIC, INTEGER, NUMERIC, TEXT, JSONB) TO anon;
GRANT EXECUTE ON FUNCTION record_batch_execution(TEXT, DATE, TEXT, INTEGER, NUMERIC, INTEGER, NUMERIC, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION system_health_check() TO anon;
GRANT EXECUTE ON FUNCTION system_health_check() TO authenticated;
GRANT EXECUTE ON FUNCTION calculate_monthly_rewards(INTEGER, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION calculate_monthly_rewards(INTEGER, INTEGER) TO authenticated;

-- 7. インデックス作成
CREATE INDEX IF NOT EXISTS idx_batch_execution_history_type_date ON batch_execution_history(batch_type, execution_date DESC);
CREATE INDEX IF NOT EXISTS idx_batch_execution_history_status ON batch_execution_history(status, created_at DESC);

-- 8. Edge Function用のWebhook URL設定テーブル
CREATE TABLE IF NOT EXISTS system_settings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    setting_key VARCHAR(100) UNIQUE NOT NULL,
    setting_value TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- デフォルト設定の挿入
INSERT INTO system_settings (setting_key, setting_value, description)
VALUES 
    ('daily_batch_enabled', 'true', '日次バッチ処理の有効/無効'),
    ('daily_batch_time', '02:00', '日次バッチ実行時刻（UTC）'),
    ('default_yield_rate', '0.015', 'デフォルト日利率（1.5%）'),
    ('default_margin_rate', '30', 'デフォルトマージン率（30%）'),
    ('webhook_url', '', 'Edge Function Webhook URL'),
    ('max_auto_batch_failures', '3', '自動バッチの最大連続失敗回数')
ON CONFLICT (setting_key) DO NOTHING;

SELECT 'Automated batch processing system implemented' as status;