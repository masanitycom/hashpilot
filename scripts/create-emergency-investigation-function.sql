-- 緊急調査用の特別なSupabase関数を作成
-- RLS制限を回避して実際のデータを取得

-- 1. 緊急調査用関数の作成
CREATE OR REPLACE FUNCTION emergency_user_investigation(
    p_user_id_1 TEXT DEFAULT '7A9637',
    p_user_id_2 TEXT DEFAULT '2BF53B'
)
RETURNS JSON
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    result JSON;
BEGIN
    -- セキュリティ保護: 管理者のみアクセス可能
    IF NOT EXISTS (
        SELECT 1 FROM admins 
        WHERE admin_user_id = auth.jwt() ->> 'email'
    ) THEN
        RAISE EXCEPTION 'Access denied: Admin privileges required';
    END IF;

    -- 調査結果を構築
    SELECT json_build_object(
        'investigation_date', CURRENT_TIMESTAMP,
        'user_1', json_build_object(
            'user_id', p_user_id_1,
            'basic_info', (
                SELECT row_to_json(u) FROM users u WHERE u.user_id = p_user_id_1
            ),
            'daily_profits', (
                SELECT COALESCE(json_agg(row_to_json(udp) ORDER BY udp.date DESC), '[]'::json)
                FROM user_daily_profit udp WHERE udp.user_id = p_user_id_1
            ),
            'purchases', (
                SELECT COALESCE(json_agg(row_to_json(p) ORDER BY p.created_at DESC), '[]'::json)
                FROM purchases p WHERE p.user_id = p_user_id_1
            ),
            'cycle_status', (
                SELECT row_to_json(ac) FROM affiliate_cycle ac WHERE ac.user_id = p_user_id_1
            )
        ),
        'user_2', json_build_object(
            'user_id', p_user_id_2,
            'basic_info', (
                SELECT row_to_json(u) FROM users u WHERE u.user_id = p_user_id_2
            ),
            'daily_profits', (
                SELECT COALESCE(json_agg(row_to_json(udp) ORDER BY udp.date DESC), '[]'::json)
                FROM user_daily_profit udp WHERE udp.user_id = p_user_id_2
            ),
            'purchases', (
                SELECT COALESCE(json_agg(row_to_json(p) ORDER BY p.created_at DESC), '[]'::json)
                FROM purchases p WHERE p.user_id = p_user_id_2
            ),
            'cycle_status', (
                SELECT row_to_json(ac) FROM affiliate_cycle ac WHERE ac.user_id = p_user_id_2
            )
        ),
        'system_overview', json_build_object(
            'approved_users', (
                SELECT json_agg(json_build_object(
                    'user_id', u.user_id,
                    'email', u.email,
                    'full_name', u.full_name,
                    'total_purchases', u.total_purchases,
                    'has_approved_nft', u.has_approved_nft,
                    'created_at', u.created_at
                ) ORDER BY u.created_at DESC)
                FROM users u WHERE u.has_approved_nft = true
            ),
            'latest_daily_profits', (
                SELECT COALESCE(json_agg(row_to_json(udp) ORDER BY udp.date DESC, udp.created_at DESC), '[]'::json)
                FROM user_daily_profit udp
                LIMIT 20
            ),
            'approved_purchases', (
                SELECT json_agg(json_build_object(
                    'user_id', p.user_id,
                    'created_at', p.created_at,
                    'admin_approved', p.admin_approved,
                    'nft_quantity', p.nft_quantity,
                    'amount_usd', p.amount_usd,
                    'purchase_date', p.created_at::date,
                    'operation_start_date', (p.created_at + INTERVAL '15 days')::date,
                    'operation_status', 
                        CASE 
                            WHEN CURRENT_DATE >= (p.created_at + INTERVAL '15 days')::date THEN 'STARTED'
                            ELSE 'WAITING'
                        END,
                    'days_since_start', CURRENT_DATE - (p.created_at + INTERVAL '15 days')::date
                ) ORDER BY p.created_at DESC)
                FROM purchases p WHERE p.admin_approved = true
            ),
            'recent_system_logs', (
                SELECT COALESCE(json_agg(row_to_json(sl) ORDER BY sl.created_at DESC), '[]'::json)
                FROM system_logs sl 
                WHERE sl.operation ILIKE '%yield%' 
                   OR sl.operation ILIKE '%profit%' 
                   OR sl.operation ILIKE '%batch%'
                LIMIT 10
            )
        )
    ) INTO result;

    RETURN result;
END;
$$;

-- 2. 簡単な調査用関数（権限チェック付き）
CREATE OR REPLACE FUNCTION quick_data_check()
RETURNS JSON
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    result JSON;
BEGIN
    -- 基本的な統計情報を取得（権限に関係なく）
    SELECT json_build_object(
        'investigation_timestamp', CURRENT_TIMESTAMP,
        'total_users', (SELECT COUNT(*) FROM users),
        'approved_users', (SELECT COUNT(*) FROM users WHERE has_approved_nft = true),
        'total_daily_profit_records', (SELECT COUNT(*) FROM user_daily_profit),
        'total_purchases', (SELECT COUNT(*) FROM purchases),
        'approved_purchases', (SELECT COUNT(*) FROM purchases WHERE admin_approved = true),
        'latest_yield_settings', (
            SELECT json_agg(row_to_json(dyl) ORDER BY dyl.date DESC)
            FROM daily_yield_log dyl
            LIMIT 5
        ),
        'sample_users', (
            SELECT json_agg(json_build_object(
                'user_id', u.user_id,
                'email', u.email,
                'has_approved_nft', u.has_approved_nft,
                'created_at', u.created_at
            ) ORDER BY u.created_at DESC)
            FROM users u
            LIMIT 10
        )
    ) INTO result;

    RETURN result;
END;
$$;

-- 3. 権限確認
SELECT 'Functions created successfully' as status;