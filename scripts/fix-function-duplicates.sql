-- 日利処理関数の重複を解消するスクリプト
-- 4引数版（古い）を削除し、5引数版（最新・月末処理対応）のみを保持

-- ========================================
-- 1. 現在の重複状況確認
-- ========================================
SELECT 
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    p.pronargs AS argument_count,
    CASE 
        WHEN p.pronargs = 4 THEN '🔴 古い版（削除対象）'
        WHEN p.pronargs = 5 THEN '🟢 最新版（保持）'
        ELSE '❓ 不明'
    END as version_status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
    AND p.proname = 'process_daily_yield_with_cycles'
ORDER BY p.pronargs;

-- ========================================
-- 2. 古い4引数版を削除
-- ========================================
DROP FUNCTION IF EXISTS process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN);

-- 削除確認ログ
INSERT INTO system_logs (
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
) VALUES (
    'SUCCESS',
    'function_duplicate_fix',
    NULL,
    '古い4引数版 process_daily_yield_with_cycles を削除しました',
    jsonb_build_object(
        'deleted_function', 'process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN)',
        'reason', '関数重複エラーの解消',
        'kept_function', 'process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN, BOOLEAN)'
    ),
    NOW()
);

-- ========================================
-- 3. 最新5引数版を再作成（念のため確実に動作するように）
-- ========================================
CREATE OR REPLACE FUNCTION process_daily_yield_with_cycles(
    p_date DATE,
    p_yield_rate NUMERIC,
    p_margin_rate NUMERIC,
    p_is_test_mode BOOLEAN DEFAULT true,
    p_is_month_end BOOLEAN DEFAULT false
)
RETURNS TABLE (
    processed_users INTEGER,
    total_profit_distributed NUMERIC,
    auto_purchases_created INTEGER,
    processing_time_seconds NUMERIC,
    test_mode BOOLEAN,
    month_end_bonus_applied BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_processing_time NUMERIC;
    v_processed_users INTEGER := 0;
    v_total_profit_distributed NUMERIC := 0;
    v_auto_purchases_created INTEGER := 0;
    v_user_record RECORD;
    v_daily_profit NUMERIC;
    v_user_rate NUMERIC;
    v_base_amount NUMERIC;
    v_cum_usdt_after_profit NUMERIC;
    v_auto_nft_purchase_count INTEGER;
    v_remaining_usdt NUMERIC;
    v_latest_purchase_date DATE;
    v_operation_started BOOLEAN;
    v_bonus_rate NUMERIC;
BEGIN
    v_start_time := NOW();
    
    -- 月末処理時のボーナス率を設定
    v_bonus_rate := CASE WHEN p_is_month_end THEN 1.05 ELSE 1.0 END;
    
    -- 日利設定をログに記録
    INSERT INTO daily_yield_log (
        date, 
        yield_rate, 
        margin_rate, 
        user_rate,
        is_month_end,
        created_at
    ) VALUES (
        p_date,
        p_yield_rate,
        p_margin_rate,
        p_yield_rate * (1 - p_margin_rate/100) * 0.6,
        p_is_month_end,
        NOW()
    );

    -- ユーザー受取率の計算
    v_user_rate := p_yield_rate * (1 - p_margin_rate/100) * 0.6;

    -- アクティブなユーザーのサイクル情報を取得
    FOR v_user_record IN 
        SELECT 
            ac.user_id,
            ac.total_nft_count,
            ac.cum_usdt,
            ac.next_action,
            COALESCE(ac.manual_nft_count, 0) as manual_nft_count,
            COALESCE(ac.auto_nft_count, 0) as auto_nft_count
        FROM affiliate_cycle ac
        JOIN users u ON ac.user_id = u.user_id
        WHERE u.is_active = true 
            AND ac.total_nft_count > 0
    LOOP
        -- 最新の承認済みNFT購入日を取得
        SELECT MAX(admin_approved_at::date)
        INTO v_latest_purchase_date
        FROM purchases
        WHERE user_id = v_user_record.user_id 
            AND admin_approved = true;

        -- 運用開始判定（承認から15日後）
        v_operation_started := false;
        IF v_latest_purchase_date IS NOT NULL THEN
            v_operation_started := (v_latest_purchase_date + INTERVAL '14 days') < p_date;
        END IF;

        -- 運用開始前のユーザーはスキップ
        IF NOT v_operation_started THEN
            CONTINUE;
        END IF;

        -- NFT運用額の計算（1NFT = 1000ドル）
        v_base_amount := v_user_record.total_nft_count * 1000;
        
        -- 月末ボーナス適用後の日利計算
        v_daily_profit := v_base_amount * v_user_rate * v_bonus_rate;

        -- 日利をユーザーの profit テーブルに記録
        INSERT INTO user_daily_profit (
            user_id,
            date,
            daily_profit,
            yield_rate,
            user_rate,
            base_amount,
            phase,
            created_at
        ) VALUES (
            v_user_record.user_id,
            p_date,
            v_daily_profit,
            p_yield_rate,
            v_user_rate,
            v_base_amount,
            CASE WHEN v_user_record.next_action = 'usdt' THEN 'USDT' ELSE 'HOLD' END,
            NOW()
        );

        -- 累積USDTに日利を加算
        v_cum_usdt_after_profit := v_user_record.cum_usdt + v_daily_profit;

        -- 自動NFT購入処理（1100ドル到達時、next_actionが'nft'の場合）
        v_auto_nft_purchase_count := 0;
        v_remaining_usdt := v_cum_usdt_after_profit;

        IF v_user_record.next_action = 'nft' THEN
            WHILE v_remaining_usdt >= 1100 LOOP
                v_auto_nft_purchase_count := v_auto_nft_purchase_count + 1;
                v_remaining_usdt := v_remaining_usdt - 1100;
                v_auto_purchases_created := v_auto_purchases_created + 1;

                -- 自動購入のpurchasesレコードを作成
                IF NOT p_is_test_mode THEN
                    INSERT INTO purchases (
                        user_id,
                        nft_quantity,
                        amount_usd,
                        payment_status,
                        admin_approved,
                        admin_approved_at,
                        admin_approved_by,
                        user_notes,
                        admin_notes,
                        is_auto_purchase,
                        created_at
                    ) VALUES (
                        v_user_record.user_id,
                        1,
                        1100,
                        'payment_confirmed',
                        true,
                        NOW(),
                        'system_auto_purchase',
                        '自動NFT購入（累積利益1100ドル到達）',
                        '自動購入システムによる処理',
                        true,
                        NOW()
                    );
                END IF;
            END LOOP;
        END IF;

        -- affiliate_cycleテーブルを更新
        UPDATE affiliate_cycle SET
            cum_usdt = v_remaining_usdt,
            auto_nft_count = COALESCE(auto_nft_count, 0) + v_auto_nft_purchase_count,
            total_nft_count = COALESCE(total_nft_count, 0) + v_auto_nft_purchase_count,
            next_action = CASE 
                WHEN v_user_record.next_action = 'usdt' THEN 'nft'
                WHEN v_user_record.next_action = 'nft' THEN 'usdt'
                ELSE 'usdt'
            END,
            updated_at = NOW()
        WHERE user_id = v_user_record.user_id;

        v_processed_users := v_processed_users + 1;
        v_total_profit_distributed := v_total_profit_distributed + v_daily_profit;
    END LOOP;

    v_end_time := NOW();
    v_processing_time := EXTRACT(EPOCH FROM (v_end_time - v_start_time));

    -- 月末処理の場合、特別なログを記録
    IF p_is_month_end THEN
        INSERT INTO system_logs (
            log_type,
            operation,
            user_id,
            message,
            details,
            created_at
        ) VALUES (
            'SUCCESS',
            'month_end_processing',
            NULL,
            '月末処理が完了しました（5%ボーナス適用）',
            jsonb_build_object(
                'processed_users', v_processed_users,
                'total_profit_distributed', v_total_profit_distributed,
                'auto_purchases_created', v_auto_purchases_created,
                'bonus_rate', v_bonus_rate,
                'processing_time_seconds', v_processing_time
            ),
            NOW()
        );

        -- 月次統計を記録
        INSERT INTO monthly_statistics (
            year,
            month,
            total_users,
            total_profit,
            total_auto_purchases,
            created_at
        ) VALUES (
            EXTRACT(YEAR FROM p_date),
            EXTRACT(MONTH FROM p_date),
            v_processed_users,
            v_total_profit_distributed,
            v_auto_purchases_created,
            NOW()
        ) ON CONFLICT (year, month) DO UPDATE SET
            total_users = EXCLUDED.total_users,
            total_profit = EXCLUDED.total_profit,
            total_auto_purchases = EXCLUDED.total_auto_purchases,
            updated_at = NOW();
    END IF;

    -- 結果を返却
    RETURN QUERY SELECT 
        v_processed_users,
        v_total_profit_distributed,
        v_auto_purchases_created,
        v_processing_time,
        p_is_test_mode,
        p_is_month_end;

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
        'daily_yield_processing',
        NULL,
        FORMAT('日利処理が完了しました（処理ユーザー数: %s）', v_processed_users),
        jsonb_build_object(
            'date', p_date,
            'yield_rate', p_yield_rate,
            'margin_rate', p_margin_rate,
            'processed_users', v_processed_users,
            'total_profit_distributed', v_total_profit_distributed,
            'auto_purchases_created', v_auto_purchases_created,
            'processing_time_seconds', v_processing_time,
            'test_mode', p_is_test_mode,
            'month_end_bonus', p_is_month_end
        ),
        NOW()
    );

EXCEPTION
    WHEN OTHERS THEN
        -- エラーログを記録
        INSERT INTO system_logs (
            log_type,
            operation,
            user_id,
            message,
            details,
            created_at
        ) VALUES (
            'ERROR',
            'daily_yield_processing',
            NULL,
            FORMAT('日利処理でエラーが発生しました: %s', SQLERRM),
            jsonb_build_object(
                'date', p_date,
                'yield_rate', p_yield_rate,
                'margin_rate', p_margin_rate,
                'error_message', SQLERRM,
                'error_state', SQLSTATE
            ),
            NOW()
        );
        
        RAISE;
END;
$$;

-- 関数の実行権限を設定
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles TO anon, authenticated;

-- ========================================
-- 4. 修正完了後の確認
-- ========================================
SELECT 
    p.proname AS function_name,
    pg_get_function_identity_arguments(p.oid) AS arguments,
    p.pronargs AS argument_count,
    CASE 
        WHEN p.pronargs = 5 THEN '✅ 最新版のみ存在'
        ELSE '❌ 予期しない状態'
    END as final_status
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
    AND p.proname = 'process_daily_yield_with_cycles'
ORDER BY p.pronargs;

-- 修正完了ログ
INSERT INTO system_logs (
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
) VALUES (
    'SUCCESS',
    'function_duplicate_resolved',
    NULL,
    'process_daily_yield_with_cycles関数の重複問題を解決しました',
    jsonb_build_object(
        'action', '古い4引数版を削除、最新5引数版を保持',
        'features', ARRAY['月末処理対応', '5%ボーナス', '改善されたエラーハンドリング', '月次統計記録'],
        'compatibility', '既存コードとの互換性維持（DEFAULTパラメータ使用）'
    ),
    NOW()
);

-- ========================================
-- 5. テスト実行（オプション）
-- ========================================
-- 修正後の動作確認用クエリ
-- SELECT * FROM process_daily_yield_with_cycles('2025-01-11', 0.016, 30, true, false);