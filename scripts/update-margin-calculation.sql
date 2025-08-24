-- マージン計算の修正：プラス利益時のみ30%マージンを適用
-- マイナス利益時はマージンを引かない

-- 1. process_daily_yield_with_cycles 関数を更新
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
    v_actual_margin_rate NUMERIC;
    v_user_record RECORD;
    v_user_profit NUMERIC;
    v_company_profit NUMERIC;
    v_base_amount NUMERIC;
    v_new_cum_usdt NUMERIC;
    v_new_available_usdt NUMERIC;
BEGIN
    -- プラス/マイナスでマージンの適用方法を変更
    IF p_yield_rate > 0 THEN
        -- プラスの場合: マージンを引く
        v_actual_margin_rate := p_margin_rate;
        v_after_margin := p_yield_rate * (1 - p_margin_rate);
        v_user_rate := v_after_margin * 0.6;
    ELSE
        -- マイナスの場合: マージンを戻す（会社が30%補填）
        v_actual_margin_rate := -p_margin_rate;  -- マイナスのマージン（補填）
        v_after_margin := p_yield_rate * (1 + p_margin_rate);  -- 1.3倍（会社が30%追加負担）
        v_user_rate := v_after_margin * 0.6;
    END IF;
    
    -- テストモードでない場合のみdaily_yield_logに記録
    IF NOT p_is_test_mode THEN
        INSERT INTO daily_yield_log (
            date, yield_rate, margin_rate, user_rate, is_month_end, created_at
        )
        VALUES (
            p_date, p_yield_rate, v_actual_margin_rate, v_user_rate, false, NOW()
        )
        ON CONFLICT (date) DO UPDATE SET
            yield_rate = EXCLUDED.yield_rate,
            margin_rate = EXCLUDED.margin_rate,
            user_rate = EXCLUDED.user_rate,
            created_at = NOW();
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
        -- 基準金額（NFT数 × 1100）
        v_base_amount := v_user_record.total_nft_count * 1100;
        
        -- ユーザー利益計算
        v_user_profit := v_base_amount * v_user_rate;
        
        -- 会社利益計算（プラス利益時のみ）
        IF p_yield_rate > 0 THEN
            v_company_profit := v_base_amount * v_actual_margin_rate + v_base_amount * v_after_margin * 0.1;
        ELSE
            v_company_profit := 0;
        END IF;
        
        -- サイクル処理
        v_new_cum_usdt := v_user_record.cum_usdt + v_user_profit;
        
        -- フェーズ判定とcum_usdt処理
        IF v_new_cum_usdt >= 2200 THEN
            -- 自動NFT購入処理
            v_auto_purchases := v_auto_purchases + 1;
            
            IF NOT p_is_test_mode THEN
                -- NFT購入処理
                UPDATE affiliate_cycle 
                SET 
                    total_nft_count = total_nft_count + 1,
                    auto_nft_count = auto_nft_count + 1,
                    cum_usdt = v_new_cum_usdt - 2200,  -- 2200引いて残りを次サイクルへ
                    available_usdt = available_usdt + 1100,  -- 1100は即時受取可能
                    phase = 'USDT',
                    cycle_number = cycle_number + 1,
                    last_updated = NOW()
                WHERE user_id = v_user_record.user_id;
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
    END LOOP;
    
    -- 結果を返す
    RETURN QUERY SELECT 
        CASE WHEN p_is_test_mode THEN 'TEST_SUCCESS' ELSE 'SUCCESS' END::TEXT,
        v_user_count::INTEGER,
        v_total_user_profit::NUMERIC,
        v_total_company_profit::NUMERIC,
        v_cycle_updates::INTEGER,
        v_auto_purchases::INTEGER,
        FORMAT('%s完了: %s名処理, %s回サイクル更新, %s回自動NFT購入', 
               CASE WHEN p_is_test_mode THEN 'テスト' ELSE '本番' END,
               v_user_count, v_cycle_updates, v_auto_purchases)::TEXT;
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
        'ERROR'::TEXT,
        0::INTEGER,
        0::NUMERIC,
        0::NUMERIC,
        0::INTEGER,
        0::INTEGER,
        FORMAT('エラー: %s', SQLERRM)::TEXT;
END;
$$;

-- 実行権限付与
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN) TO anon;
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN) TO authenticated;

-- テスト実行（プラス利益）
SELECT '--- プラス利益時のテスト (1.6% 日利, 30% マージン) ---' as test_case;
SELECT * FROM process_daily_yield_with_cycles('2025-01-24', 0.016, 0.30, true);

-- テスト実行（マイナス利益）
SELECT '--- マイナス利益時のテスト (-1.0% 日利, マージンなし) ---' as test_case;
SELECT * FROM process_daily_yield_with_cycles('2025-01-24', -0.010, 0.30, true);

-- 2. 月末処理対応の日利処理関数も更新
CREATE OR REPLACE FUNCTION process_daily_yield_with_cycles(
    p_date DATE,
    p_yield_rate NUMERIC,
    p_margin_rate NUMERIC,
    p_is_test_mode BOOLEAN DEFAULT true,
    p_is_month_end BOOLEAN DEFAULT false
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
    v_actual_margin_rate NUMERIC;
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
    v_month_profit_sum NUMERIC := 0;
BEGIN
    v_start_time := NOW();
    
    -- 月末処理の場合、当月の累計利益を計算
    IF p_is_month_end AND NOT p_is_test_mode THEN
        -- 当月の累計利益を計算
        SELECT COALESCE(SUM(daily_profit), 0) INTO v_month_profit_sum
        FROM user_daily_profit
        WHERE date >= date_trunc('month', p_date)
          AND date <= p_date;
          
        PERFORM log_system_event(
            'INFO',
            'MONTHLY_PROCESSING',
            NULL,
            FORMAT('月末処理開始: 日付=%s, 利率=%s%%, マージン=%s%%, 当月累計利益=$%s', 
                   p_date, p_yield_rate * 100, p_margin_rate * 100, v_month_profit_sum),
            jsonb_build_object(
                'date', p_date,
                'yield_rate', p_yield_rate,
                'margin_rate', p_margin_rate,
                'test_mode', p_is_test_mode,
                'month_total_profit', v_month_profit_sum
            )
        );
    END IF;
    
    -- プラス/マイナスでマージンの適用方法を変更
    IF p_yield_rate > 0 THEN
        -- プラスの場合: マージンを引く
        v_actual_margin_rate := p_margin_rate;
        v_after_margin := p_yield_rate * (1 - p_margin_rate);
        v_user_rate := v_after_margin * 0.6;
    ELSE
        -- マイナスの場合: マージンを戻す（会社が30%補填）
        v_actual_margin_rate := -p_margin_rate;  -- マイナスのマージン（補填）
        v_after_margin := p_yield_rate * (1 + p_margin_rate);  -- 1.3倍（会社が30%追加負担）
        v_user_rate := v_after_margin * 0.6;
    END IF;
    
    -- テストモードでない場合のみdaily_yield_logに記録
    IF NOT p_is_test_mode THEN
        INSERT INTO daily_yield_log (
            date, yield_rate, margin_rate, user_rate, is_month_end, created_at
        )
        VALUES (
            p_date, p_yield_rate, v_actual_margin_rate, v_user_rate, p_is_month_end, NOW()
        )
        ON CONFLICT (date) DO UPDATE SET
            yield_rate = EXCLUDED.yield_rate,
            margin_rate = EXCLUDED.margin_rate,
            user_rate = EXCLUDED.user_rate,
            is_month_end = EXCLUDED.is_month_end,
            created_at = NOW();
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
            
            -- 月末処理の場合、当月の累計利益に対してマージンを再計算
            IF p_is_month_end THEN
                -- 月末処理: 当月の累計利益を取得
                DECLARE
                    v_user_month_profit NUMERIC;
                BEGIN
                    SELECT COALESCE(SUM(daily_profit), 0) INTO v_user_month_profit
                    FROM user_daily_profit
                    WHERE user_id = v_user_record.user_id
                      AND date >= date_trunc('month', p_date)
                      AND date < p_date; -- 当日分は含まない
                    
                    -- 当月累計利益に今日の分を加算
                    v_user_month_profit := v_user_month_profit + v_user_profit;
                    
                    -- 累計がプラスの場合のみマージンを適用
                    IF v_user_month_profit > 0 THEN
                        -- 月末調整: 累計利益に対して30%マージンを適用
                        v_user_profit := v_user_month_profit * (1 - p_margin_rate) * 0.6 - (v_user_month_profit - v_user_profit) * 0.6;
                    END IF;
                END;
            END IF;
            
            -- 会社利益計算（プラス利益時のみ）
            IF p_yield_rate > 0 THEN
                v_company_profit := v_base_amount * v_actual_margin_rate + v_base_amount * v_after_margin * 0.1;
            ELSE
                v_company_profit := 0;
            END IF;
            
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
        END;
    END LOOP;
    
    -- 月末処理完了時の特別処理
    IF p_is_month_end AND NOT p_is_test_mode THEN
        -- 月次統計の記録
        INSERT INTO monthly_statistics (
            year, month, total_users, total_profit, total_auto_purchases, created_at
        )
        VALUES (
            EXTRACT(YEAR FROM p_date),
            EXTRACT(MONTH FROM p_date),
            v_user_count,
            v_total_user_profit,
            v_auto_purchases,
            NOW()
        )
        ON CONFLICT (year, month) DO UPDATE SET
            total_users = EXCLUDED.total_users,
            total_profit = EXCLUDED.total_profit,
            total_auto_purchases = EXCLUDED.total_auto_purchases,
            updated_at = NOW();
    END IF;
    
    -- 完了ログ
    v_log_details := jsonb_build_object(
        'execution_time_ms', EXTRACT(EPOCH FROM (NOW() - v_start_time)) * 1000,
        'users_processed', v_user_count,
        'total_user_profit', v_total_user_profit,
        'total_company_profit', v_total_company_profit,
        'cycle_updates', v_cycle_updates,
        'auto_purchases', v_auto_purchases,
        'error_count', v_error_count,
        'is_month_end', p_is_month_end
    );
    
    PERFORM log_system_event(
        CASE WHEN v_error_count = 0 THEN 'SUCCESS' ELSE 'WARNING' END,
        CASE WHEN p_is_month_end THEN 'MONTHLY_PROCESSING' ELSE 'DAILY_YIELD' END,
        NULL,
        FORMAT('%s処理完了: %s名処理, %s回サイクル更新, %s回自動購入, %sエラー', 
               CASE WHEN p_is_month_end THEN '月末' ELSE '日利' END,
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
        FORMAT('%s完了: %s名処理, %s回サイクル更新, %s回自動NFT購入%s%s', 
               CASE WHEN p_is_test_mode THEN 'テスト' ELSE '本番' END,
               v_user_count, v_cycle_updates, v_auto_purchases,
               CASE WHEN p_is_month_end THEN ' (月末調整適用)' ELSE '' END,
               CASE WHEN v_error_count > 0 THEN FORMAT(' (%sエラー)', v_error_count) ELSE '' END)::TEXT;
    
EXCEPTION WHEN OTHERS THEN
    -- 致命的なエラー
    PERFORM log_system_event(
        'ERROR',
        CASE WHEN p_is_month_end THEN 'MONTHLY_PROCESSING' ELSE 'DAILY_YIELD' END,
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

-- 権限付与
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN, BOOLEAN) TO anon;
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN, BOOLEAN) TO authenticated;

-- 月末処理のテスト実行（プラス利益）
SELECT '--- 月末処理テスト (プラス利益, 30%マージン適用) ---' as test_case;
SELECT * FROM process_daily_yield_with_cycles('2025-01-31', 0.020, 0.30, true, true);

-- 月末処理のテスト実行（マイナス利益）
SELECT '--- 月末処理テスト (マイナス利益, マージンなし) ---' as test_case;
SELECT * FROM process_daily_yield_with_cycles('2025-01-31', -0.015, 0.30, true, true);