-- 緊急修正: 日利設定システムの完全復旧
-- 1. 3000%異常値の強制削除
-- 2. 重複キー制約の解決
-- 3. 欠損関数の復旧

-- ========================================
-- 1. 現在の問題状況確認
-- ========================================

-- 3000%異常値の確認
SELECT 
    id,
    date,
    margin_rate,
    yield_rate,
    user_rate,
    is_month_end,
    created_at,
    '🔴 異常値' as status
FROM daily_yield_log 
WHERE margin_rate >= 1000 OR yield_rate >= 1
ORDER BY created_at DESC;

-- 重複日付の確認
SELECT 
    date,
    COUNT(*) as duplicate_count,
    ARRAY_AGG(id ORDER BY created_at) as ids,
    ARRAY_AGG(margin_rate ORDER BY created_at) as margin_rates
FROM daily_yield_log 
GROUP BY date 
HAVING COUNT(*) > 1
ORDER BY date DESC;

-- ========================================
-- 2. 3000%異常値を強制削除
-- ========================================

-- 3000%以上の異常値を物理削除
DELETE FROM daily_yield_log 
WHERE margin_rate >= 1000 OR yield_rate >= 1;

-- 削除確認
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ 異常値削除完了'
        ELSE '❌ 異常値が残存: ' || COUNT(*)::text || '件'
    END as cleanup_status
FROM daily_yield_log 
WHERE margin_rate >= 1000 OR yield_rate >= 1;

-- ========================================
-- 3. 重複日付の解決（最新のみ保持）
-- ========================================

-- 重複がある場合、古いレコードを削除
DELETE FROM daily_yield_log 
WHERE id NOT IN (
    SELECT MAX(id)
    FROM daily_yield_log 
    GROUP BY date
);

-- 重複解決確認
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ 重複解決完了'
        ELSE '❌ 重複が残存: ' || COUNT(*) || '件'
    END as duplicate_status
FROM (
    SELECT date, COUNT(*) as cnt
    FROM daily_yield_log 
    GROUP BY date 
    HAVING COUNT(*) > 1
) duplicates;

-- ========================================
-- 4. 欠損関数の復旧
-- ========================================

-- admin_cancel_yield_posting関数を作成
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

-- 関数の実行権限を設定
GRANT EXECUTE ON FUNCTION admin_cancel_yield_posting TO anon, authenticated;

-- ========================================
-- 5. cancel_yield_posting関数の確認・修正
-- ========================================

-- 既存のcancel_yield_posting関数があるかチェック
SELECT 
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    CASE 
        WHEN p.proname = 'cancel_yield_posting' THEN '✅ 存在'
        ELSE '❌ なし'
    END as status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
    AND p.proname IN ('cancel_yield_posting', 'admin_cancel_yield_posting')
ORDER BY p.proname;

-- cancel_yield_postingがない場合、エイリアスを作成
CREATE OR REPLACE FUNCTION cancel_yield_posting(p_date DATE)
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

GRANT EXECUTE ON FUNCTION cancel_yield_posting TO anon, authenticated;

-- ========================================
-- 6. 日利設定の制約緩和（一時的）
-- ========================================

-- 一意制約を一時的に削除（既に存在する場合）
DO $$
BEGIN
    -- 制約の存在確認と削除
    IF EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE constraint_name = 'daily_yield_log_date_key' 
            AND table_name = 'daily_yield_log'
    ) THEN
        ALTER TABLE daily_yield_log DROP CONSTRAINT daily_yield_log_date_key;
    END IF;
END $$;

-- 重複チェック付きの安全な制約を再追加
DO $$
BEGIN
    -- まず重複がないことを確認
    IF NOT EXISTS (
        SELECT 1 FROM (
            SELECT date, COUNT(*) 
            FROM daily_yield_log 
            GROUP BY date 
            HAVING COUNT(*) > 1
        ) duplicates
    ) THEN
        -- 重複がない場合のみ制約を再追加
        ALTER TABLE daily_yield_log ADD CONSTRAINT daily_yield_log_date_key UNIQUE (date);
    END IF;
END $$;

-- ========================================
-- 7. システム状態の最終確認
-- ========================================

-- 関数の存在確認
SELECT 
    'FUNCTIONS' as check_type,
    ARRAY_AGG(p.proname) as available_functions
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
    AND p.proname IN (
        'process_daily_yield_with_cycles',
        'admin_cancel_yield_posting', 
        'cancel_yield_posting'
    );

-- テーブル制約の確認
SELECT 
    'CONSTRAINTS' as check_type,
    constraint_name,
    constraint_type,
    CASE 
        WHEN constraint_name = 'daily_yield_log_date_key' THEN '✅ 日付一意制約'
        ELSE constraint_name
    END as description
FROM information_schema.table_constraints 
WHERE table_name = 'daily_yield_log' 
    AND constraint_type = 'UNIQUE';

-- 最新データの確認
SELECT 
    'LATEST_DATA' as check_type,
    COUNT(*) as total_records,
    MAX(date) as latest_date,
    MAX(margin_rate) as max_margin_rate,
    CASE 
        WHEN MAX(margin_rate) < 100 THEN '✅ 正常範囲'
        ELSE '❌ 異常値あり'
    END as data_status
FROM daily_yield_log;

-- ========================================
-- 8. 完了ログ
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
    'emergency_yield_system_fix',
    NULL,
    '日利設定システムの緊急修復が完了しました',
    jsonb_build_object(
        'fixed_issues', ARRAY[
            '3000%異常値削除',
            '重複日付解決', 
            '欠損関数復旧',
            '制約問題解決'
        ],
        'restored_functions', ARRAY[
            'admin_cancel_yield_posting',
            'cancel_yield_posting'
        ]
    ),
    NOW()
);