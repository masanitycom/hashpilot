-- cancel_yield_posting関数の修正
-- 既存関数を削除して正しい戻り値型で再作成

-- ========================================
-- 1. 既存関数を削除
-- ========================================
DROP FUNCTION IF EXISTS cancel_yield_posting(DATE) CASCADE;

-- ========================================
-- 2. admin_cancel_yield_posting関数を作成
-- ========================================
CREATE OR REPLACE FUNCTION admin_cancel_yield_posting(p_date DATE)
RETURNS TABLE (
    deleted_yield_records INTEGER,
    deleted_profit_records INTEGER,
    success BOOLEAN,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted_yield INTEGER := 0;
    v_deleted_profit INTEGER := 0;
BEGIN
    -- daily_yield_logから該当日のレコードを削除
    DELETE FROM daily_yield_log 
    WHERE date = p_date;
    
    GET DIAGNOSTICS v_deleted_yield = ROW_COUNT;
    
    -- user_daily_profitから該当日のレコードを削除
    DELETE FROM user_daily_profit 
    WHERE date = p_date;
    
    GET DIAGNOSTICS v_deleted_profit = ROW_COUNT;
    
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
        'admin_cancel_yield_posting',
        NULL,
        FORMAT('管理者が%sの日利設定をキャンセルしました', p_date),
        jsonb_build_object(
            'date', p_date,
            'deleted_yield_records', v_deleted_yield,
            'deleted_profit_records', v_deleted_profit
        ),
        NOW()
    );
    
    RETURN QUERY SELECT 
        v_deleted_yield,
        v_deleted_profit,
        true,
        FORMAT('削除完了: 日利設定%s件、利益記録%s件', v_deleted_yield, v_deleted_profit);

EXCEPTION
    WHEN OTHERS THEN
        -- エラーログ
        INSERT INTO system_logs (
            log_type,
            operation,
            user_id,
            message,
            details,
            created_at
        ) VALUES (
            'ERROR',
            'admin_cancel_yield_posting',
            NULL,
            FORMAT('日利キャンセルでエラー: %s', SQLERRM),
            jsonb_build_object(
                'date', p_date,
                'error_message', SQLERRM,
                'error_state', SQLSTATE
            ),
            NOW()
        );
        
        RETURN QUERY SELECT 
            0,
            0,
            false,
            FORMAT('エラー: %s', SQLERRM);
END;
$$;

-- ========================================
-- 3. cancel_yield_posting関数を新規作成（同じ戻り値型）
-- ========================================
CREATE FUNCTION cancel_yield_posting(p_date DATE)
RETURNS TABLE (
    deleted_yield_records INTEGER,
    deleted_profit_records INTEGER,
    success BOOLEAN,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- admin_cancel_yield_postingを呼び出すだけ
    RETURN QUERY SELECT * FROM admin_cancel_yield_posting(p_date);
END;
$$;

-- ========================================
-- 4. 権限設定
-- ========================================
GRANT EXECUTE ON FUNCTION admin_cancel_yield_posting TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cancel_yield_posting TO anon, authenticated;

-- ========================================
-- 5. 関数確認
-- ========================================
SELECT 
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    '✅ 作成完了' as status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
    AND p.proname IN ('admin_cancel_yield_posting', 'cancel_yield_posting')
ORDER BY p.proname;

-- ========================================
-- 6. テスト実行（実際には削除しない）
-- ========================================
-- 明日の日付でテスト（存在しないのでエラーにならない）
SELECT 
    'TEST' as test_type,
    deleted_yield_records,
    deleted_profit_records,
    success,
    message
FROM admin_cancel_yield_posting(CURRENT_DATE + INTERVAL '1 day');

-- 完了ログ
INSERT INTO system_logs (
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
) VALUES (
    'SUCCESS',
    'cancel_function_fix',
    NULL,
    'キャンセル関数の修復が完了しました',
    jsonb_build_object(
        'action', 'cancel_yield_posting関数を削除・再作成',
        'new_functions', ARRAY['admin_cancel_yield_posting', 'cancel_yield_posting']
    ),
    NOW()
);