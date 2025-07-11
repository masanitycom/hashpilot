-- 管理者専用の日利設定キャンセル関数を作成

CREATE OR REPLACE FUNCTION admin_cancel_yield_posting(p_date DATE)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    deleted_yield_count INTEGER;
    deleted_profit_count INTEGER;
    result JSON;
BEGIN
    -- daily_yield_logから削除
    DELETE FROM daily_yield_log WHERE date = p_date;
    GET DIAGNOSTICS deleted_yield_count = ROW_COUNT;
    
    -- user_daily_profitから削除
    DELETE FROM user_daily_profit WHERE date = p_date;
    GET DIAGNOSTICS deleted_profit_count = ROW_COUNT;
    
    -- 結果をJSONで返す
    result := json_build_object(
        'success', true,
        'message', format('日利設定をキャンセルしました: yield_log %s件, profit %s件削除', deleted_yield_count, deleted_profit_count),
        'deleted_yield_count', deleted_yield_count,
        'deleted_profit_count', deleted_profit_count,
        'date', p_date
    );
    
    RETURN result;
END;
$$;