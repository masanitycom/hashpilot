-- キャンセル関数のデバッグと修正

-- ========================================
-- 1. 現在の関数の戻り値型を確認
-- ========================================
SELECT 
    p.proname AS function_name,
    pg_get_function_result(p.oid) AS return_type,
    pg_get_function_identity_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
    AND p.proname = 'admin_cancel_yield_posting';

-- ========================================
-- 2. 実際の今日の日利データを確認
-- ========================================
SELECT 
    id,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
FROM daily_yield_log 
WHERE date = CURRENT_DATE
ORDER BY created_at DESC;

-- ========================================
-- 3. 関数の実際の動作テスト（今日のデータで）
-- ========================================
SELECT 
    'REAL_TEST' as test_type,
    deleted_yield_records,
    deleted_profit_records,
    success,
    message
FROM admin_cancel_yield_posting(CURRENT_DATE);

-- ========================================
-- 4. テスト後の状態確認
-- ========================================
SELECT 
    'AFTER_DELETE' as check_type,
    COUNT(*) as remaining_records
FROM daily_yield_log 
WHERE date = CURRENT_DATE;

-- ========================================
-- 5. フロントエンド用の修正版関数を作成
-- ========================================
CREATE OR REPLACE FUNCTION admin_cancel_yield_posting_v2(p_date DATE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted_yield INTEGER := 0;
    v_deleted_profit INTEGER := 0;
    v_result JSONB;
BEGIN
    -- daily_yield_logから該当日のレコードを削除
    DELETE FROM daily_yield_log 
    WHERE date = p_date;
    
    GET DIAGNOSTICS v_deleted_yield = ROW_COUNT;
    
    -- user_daily_profitから該当日のレコードを削除
    DELETE FROM user_daily_profit 
    WHERE date = p_date;
    
    GET DIAGNOSTICS v_deleted_profit = ROW_COUNT;
    
    -- 結果をJSONBで返す
    v_result := jsonb_build_object(
        'success', true,
        'message', FORMAT('削除完了: 日利設定%s件、利益記録%s件', v_deleted_yield, v_deleted_profit),
        'deleted_yield_records', v_deleted_yield,
        'deleted_profit_records', v_deleted_profit,
        'date', p_date
    );
    
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
        'admin_cancel_yield_posting_v2',
        NULL,
        FORMAT('管理者が%sの日利設定をキャンセルしました', p_date),
        v_result,
        NOW()
    );
    
    RETURN v_result;

EXCEPTION
    WHEN OTHERS THEN
        -- エラー時もJSONBで返す
        v_result := jsonb_build_object(
            'success', false,
            'message', FORMAT('エラー: %s', SQLERRM),
            'deleted_yield_records', 0,
            'deleted_profit_records', 0,
            'error_code', SQLSTATE
        );
        
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
            'admin_cancel_yield_posting_v2',
            NULL,
            FORMAT('日利キャンセルでエラー: %s', SQLERRM),
            v_result,
            NOW()
        );
        
        RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION admin_cancel_yield_posting_v2 TO anon, authenticated;

-- ========================================
-- 6. 新しい関数のテスト
-- ========================================
SELECT admin_cancel_yield_posting_v2('2025-01-11'::DATE) as test_result;