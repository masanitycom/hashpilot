-- エラーハンドリングとログ機能の強化

-- 1. システムログテーブルの作成
CREATE TABLE IF NOT EXISTS system_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    log_type VARCHAR(50) NOT NULL, -- 'ERROR', 'WARNING', 'INFO', 'SUCCESS'
    operation VARCHAR(100) NOT NULL, -- 'DAILY_YIELD', 'AUTO_PURCHASE', 'CYCLE_UPDATE'
    user_id TEXT,
    message TEXT NOT NULL,
    details JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- 2. システムログ記録関数
CREATE OR REPLACE FUNCTION log_system_event(
    p_log_type TEXT,
    p_operation TEXT,
    p_user_id TEXT DEFAULT NULL,
    p_message TEXT,
    p_details JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO system_logs (log_type, operation, user_id, message, details, created_at)
    VALUES (p_log_type, p_operation, p_user_id, p_message, p_details, NOW())
    RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
EXCEPTION WHEN OTHERS THEN
    -- ログ記録自体が失敗した場合はNULLを返す
    RETURN NULL;
END;
$$;

-- 3. 改良版のprocess_daily_yield_with_cycles関数（エラーハンドリング強化）
CREATE OR REPLACE FUNCTION process_daily_yield_with_cycles(
    p_date DATE,
    p_yield_rate NUMERIC,
    p_margin_rate NUMERIC,
    p_is_test_mode BOOLEAN DEFAULT true
)
RETURNS TABLE(
    status text,
    total_users integer,
    total_user_profit numeric,
    total_company_profit numeric,
    cycle_updates integer,
    auto_nft_purchases integer,
    message text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_count INTEGER := 0;
    v_total_user_profit NUMERIC := 0;
    v_total_company_profit NUMERIC := 0;
    v_cycle_updates INTEGER := 0;
    v_auto_purchases INTEGER := 0;
    v_user_rate NUMERIC;
    v_after_margin NUMERIC;
    v_user_record RECORD;
    v_user_profit NUMERIC;
    v_company_profit NUMERIC;
    v_base_amount NUMERIC;
    v_new_cum_usdt NUMERIC;
    v_new_available_usdt NUMERIC;
    v_purchase_result RECORD;
    v_error_count INTEGER := 0;
    v_start_time TIMESTAMP;
    v_log_details JSONB;
BEGIN
    v_start_time := NOW();
    
    -- 開始ログ
    PERFORM log_system_event(
        'INFO',
        'DAILY_YIELD',
        NULL,
        FORMAT('日利処理開始: 日付=%s, 利率=%s%%, マージン=%s%%, モード=%s', 
               p_date, p_yield_rate * 100, p_margin_rate * 100, 
               CASE WHEN p_is_test_mode THEN 'TEST' ELSE 'PRODUCTION' END),
        jsonb_build_object(
            'date', p_date,
            'yield_rate', p_yield_rate,
            'margin_rate', p_margin_rate,
            'test_mode', p_is_test_mode
        )
    );
    
    -- 入力値検証
    IF p_yield_rate IS NULL OR p_margin_rate IS NULL THEN
        PERFORM log_system_event('ERROR', 'DAILY_YIELD', NULL, '無効な入力値: 利率またはマージン率がNULL');
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 0::INTEGER, 0::NUMERIC, 0::NUMERIC, 0::INTEGER, 0::INTEGER,
            '無効な入力値です'::TEXT;
        RETURN;
    END IF;
    
    IF p_yield_rate < -1 OR p_yield_rate > 1 THEN
        PERFORM log_system_event('ERROR', 'DAILY_YIELD', NULL, FORMAT('異常な日利率: %s%%', p_yield_rate * 100));
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 0::INTEGER, 0::NUMERIC, 0::NUMERIC, 0::INTEGER, 0::INTEGER,
            '日利率が許容範囲外です (-100% to 100%)'::TEXT;
        RETURN;
    END IF;
    
    -- 利率計算
    v_after_margin := p_yield_rate * (1 - p_margin_rate / 100);
    v_user_rate := v_after_margin * 0.6;
    
    -- テストモードでない場合のみdaily_yield_logに記録
    IF NOT p_is_test_mode THEN
        BEGIN
            INSERT INTO daily_yield_log (
                date, yield_rate, margin_rate, user_rate, is_month_end, created_at
            )
            VALUES (
                p_date, p_yield_rate, p_margin_rate, v_user_rate, false, NOW()
            )
            ON CONFLICT (date) DO UPDATE SET
                yield_rate = EXCLUDED.yield_rate,
                margin_rate = EXCLUDED.margin_rate,
                user_rate = EXCLUDED.user_rate,
                created_at = NOW();
        EXCEPTION WHEN OTHERS THEN
            PERFORM log_system_event('ERROR', 'DAILY_YIELD', NULL, 
                FORMAT('daily_yield_log挿入エラー: %s', SQLERRM));
            v_error_count := v_error_count + 1;
        END;
    END IF;
    
    -- 各ユーザーの処理
    FOR v_user_record IN
        SELECT 
            user_id,
            phase,
            total_nft_count,
            cum_usdt,
            available_usdt,
            auto_nft_count,
            manual_nft_count
        FROM affiliate_cycle 
        WHERE total_nft_count > 0
    LOOP
        BEGIN
            -- 基準金額（NFT数 × 1100）
            v_base_amount := v_user_record.total_nft_count * 1100;
            
            -- ユーザー利益計算
            v_user_profit := v_base_amount * v_user_rate;
            
            -- 会社利益計算
            v_company_profit := v_base_amount * p_margin_rate / 100 + v_base_amount * v_after_margin * 0.1;
            
            -- サイクル処理
            v_new_cum_usdt := v_user_record.cum_usdt + v_user_profit;
            
            -- フェーズ判定とcum_usdt処理
            IF v_new_cum_usdt >= 2200 THEN
                -- 自動NFT購入処理
                v_auto_purchases := v_auto_purchases + 1;
                
                IF NOT p_is_test_mode THEN
                    -- purchasesテーブルに自動購入記録を追加
                    SELECT * FROM record_auto_nft_purchase(v_user_record.user_id, 1) INTO v_purchase_result;
                    
                    -- affiliate_cycleテーブルを更新
                    UPDATE affiliate_cycle 
                    SET 
                        total_nft_count = total_nft_count + 1,
                        auto_nft_count = auto_nft_count + 1,
                        cum_usdt = v_new_cum_usdt - 2200,
                        available_usdt = available_usdt + 1100,
                        phase = 'USDT',
                        cycle_number = cycle_number + 1,
                        last_updated = NOW()
                    WHERE user_id = v_user_record.user_id;
                    
                    -- 自動購入ログ
                    PERFORM log_system_event(
                        'SUCCESS',
                        'AUTO_PURCHASE',
                        v_user_record.user_id,
                        FORMAT('自動NFT購入完了: サイクル%s, 累積$%s → $%s', 
                               v_user_record.auto_nft_count + 1, v_new_cum_usdt, v_new_cum_usdt - 2200),
                        jsonb_build_object(
                            'old_cum_usdt', v_new_cum_usdt,
                            'new_cum_usdt', v_new_cum_usdt - 2200,
                            'nft_purchased', 1,
                            'available_added', 1100
                        )
                    );
                END IF;
                
                v_cycle_updates := v_cycle_updates + 1;
                
            ELSIF v_new_cum_usdt >= 1100 THEN
                -- HOLDフェーズ
                IF NOT p_is_test_mode THEN
                    UPDATE affiliate_cycle 
                    SET 
                        cum_usdt = v_new_cum_usdt,
                        phase = 'HOLD',
                        last_updated = NOW()
                    WHERE user_id = v_user_record.user_id;
                END IF;
                
                v_cycle_updates := v_cycle_updates + 1;
                
            ELSE
                -- USDTフェーズ（即時受取可能）
                IF NOT p_is_test_mode THEN
                    UPDATE affiliate_cycle 
                    SET 
                        cum_usdt = v_new_cum_usdt,
                        available_usdt = available_usdt + v_user_profit,
                        phase = 'USDT',
                        last_updated = NOW()
                    WHERE user_id = v_user_record.user_id;
                END IF;
                
                v_cycle_updates := v_cycle_updates + 1;
            END IF;
            
            -- user_daily_profitテーブルに記録（テストモードでない場合のみ）
            IF NOT p_is_test_mode THEN
                DELETE FROM user_daily_profit WHERE user_id = v_user_record.user_id AND date = p_date;
                
                INSERT INTO user_daily_profit (
                    user_id, date, daily_profit, yield_rate, user_rate, base_amount, phase, created_at
                )
                VALUES (
                    v_user_record.user_id, p_date, v_user_profit, p_yield_rate, v_user_rate, v_base_amount, 
                    CASE WHEN v_new_cum_usdt >= 1100 THEN 'HOLD' ELSE 'USDT' END, NOW()
                );
            END IF;
            
            v_user_count := v_user_count + 1;
            v_total_user_profit := v_total_user_profit + v_user_profit;
            v_total_company_profit := v_total_company_profit + v_company_profit;
            
        EXCEPTION WHEN OTHERS THEN
            -- ユーザー個別のエラーログ
            PERFORM log_system_event(
                'ERROR',
                'DAILY_YIELD',
                v_user_record.user_id,
                FORMAT('ユーザー処理エラー: %s', SQLERRM),
                jsonb_build_object(
                    'error_code', SQLSTATE,
                    'user_data', row_to_json(v_user_record)
                )
            );
            v_error_count := v_error_count + 1;
            -- エラーがあっても処理を続行
        END;
    END LOOP;
    
    -- 完了ログ
    v_log_details := jsonb_build_object(
        'execution_time_ms', EXTRACT(EPOCH FROM (NOW() - v_start_time)) * 1000,
        'users_processed', v_user_count,
        'total_user_profit', v_total_user_profit,
        'total_company_profit', v_total_company_profit,
        'cycle_updates', v_cycle_updates,
        'auto_purchases', v_auto_purchases,
        'error_count', v_error_count
    );
    
    PERFORM log_system_event(
        CASE WHEN v_error_count = 0 THEN 'SUCCESS' ELSE 'WARNING' END,
        'DAILY_YIELD',
        NULL,
        FORMAT('日利処理完了: %s名処理, %s回サイクル更新, %s回自動購入, %sエラー', 
               v_user_count, v_cycle_updates, v_auto_purchases, v_error_count),
        v_log_details
    );
    
    -- 結果を返す
    RETURN QUERY SELECT 
        CASE 
            WHEN p_is_test_mode THEN 'TEST_SUCCESS' 
            WHEN v_error_count = 0 THEN 'SUCCESS'
            ELSE 'WARNING'
        END::TEXT,
        v_user_count::INTEGER,
        v_total_user_profit::NUMERIC,
        v_total_company_profit::NUMERIC,
        v_cycle_updates::INTEGER,
        v_auto_purchases::INTEGER,
        FORMAT('%s完了: %s名処理, %s回サイクル更新, %s回自動NFT購入%s', 
               CASE WHEN p_is_test_mode THEN 'テスト' ELSE '本番' END,
               v_user_count, v_cycle_updates, v_auto_purchases,
               CASE WHEN v_error_count > 0 THEN FORMAT(' (%sエラー)', v_error_count) ELSE '' END)::TEXT;
    
EXCEPTION WHEN OTHERS THEN
    -- 致命的なエラー
    PERFORM log_system_event(
        'ERROR',
        'DAILY_YIELD',
        NULL,
        FORMAT('致命的エラー: %s', SQLERRM),
        jsonb_build_object(
            'error_code', SQLSTATE,
            'execution_time_ms', EXTRACT(EPOCH FROM (NOW() - v_start_time)) * 1000
        )
    );
    
    RETURN QUERY SELECT 
        'ERROR'::TEXT,
        0::INTEGER,
        0::NUMERIC,
        0::NUMERIC,
        0::INTEGER,
        0::INTEGER,
        FORMAT('システムエラー: %s', SQLERRM)::TEXT;
END;
$$;

-- 4. システムログ取得関数
CREATE OR REPLACE FUNCTION get_system_logs(
    p_log_type TEXT DEFAULT NULL,
    p_operation TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE(
    id UUID,
    log_type TEXT,
    operation TEXT,
    user_id TEXT,
    message TEXT,
    details JSONB,
    created_at TIMESTAMP
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT sl.id, sl.log_type, sl.operation, sl.user_id, sl.message, sl.details, sl.created_at
    FROM system_logs sl
    WHERE (p_log_type IS NULL OR sl.log_type = p_log_type)
      AND (p_operation IS NULL OR sl.operation = p_operation)
    ORDER BY sl.created_at DESC
    LIMIT p_limit;
END;
$$;

-- 5. 実行権限付与
GRANT EXECUTE ON FUNCTION log_system_event(TEXT, TEXT, TEXT, TEXT, JSONB) TO anon;
GRANT EXECUTE ON FUNCTION log_system_event(TEXT, TEXT, TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION get_system_logs(TEXT, TEXT, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION get_system_logs(TEXT, TEXT, INTEGER) TO authenticated;

-- 6. システムログテーブルのインデックス作成
CREATE INDEX IF NOT EXISTS idx_system_logs_type_created ON system_logs(log_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_system_logs_operation_created ON system_logs(operation, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_system_logs_user_created ON system_logs(user_id, created_at DESC);

SELECT 'Enhanced error handling and logging system implemented' as status;