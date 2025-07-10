-- 日利計算の0.6倍バグを修正

-- 現在の関数を削除して新しいものを作成
DROP FUNCTION IF EXISTS process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN);

-- 修正版の関数を作成
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
BEGIN
    -- 利率計算（修正：0.6倍を削除）
    v_after_margin := p_yield_rate * (1 - p_margin_rate / 100);
    v_user_rate := v_after_margin; -- 修正：0.6を削除
    
    -- テストモードでない場合のみdaily_yield_logに記録
    IF NOT p_is_test_mode THEN
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
        
        -- ユーザー利益計算（修正済み）
        v_user_profit := v_base_amount * v_user_rate;
        
        -- 会社利益計算（修正：0.1倍を削除）
        v_company_profit := v_base_amount * p_margin_rate / 100;
        
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
    
    RETURN QUERY SELECT 
        'success'::text,
        v_user_count,
        v_total_user_profit,
        v_total_company_profit,
        v_cycle_updates,
        v_auto_purchases,
        CASE 
            WHEN p_is_test_mode THEN 
                format('テスト完了: %s名処理予定、ユーザー総利益$%s、会社総利益$%s', 
                       v_user_count, v_total_user_profit::text, v_total_company_profit::text)
            ELSE 
                format('処理完了: %s名に総額$%sの利益を配布', 
                       v_user_count, v_total_user_profit::text)
        END;
END;
$$;

-- 既存の日利データを修正（7月分のみ）
UPDATE user_daily_profit 
SET daily_profit = daily_profit / 0.6
WHERE date >= '2025-07-01' 
AND date <= '2025-07-31';

-- 修正完了メッセージ
SELECT '日利計算の0.6倍バグを修正しました。既存の7月データも正しい値に更新されました。' as message;