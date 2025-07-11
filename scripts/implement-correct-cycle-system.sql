-- 正しい交互サイクル処理システムの実装

-- 1. affiliate_cycleテーブルに必要なカラムを追加
ALTER TABLE affiliate_cycle ADD COLUMN IF NOT EXISTS next_action TEXT DEFAULT 'usdt';
-- 'usdt' = 次は1100ドルUSDT受取、'nft' = 次は1100ドルNFT購入

-- 2. 既存データの次アクション判定を更新
UPDATE affiliate_cycle
SET next_action = CASE
    -- cum_usdt < 1100の場合
    WHEN cum_usdt < 1100 THEN 
        CASE 
            -- 現在のcycle_numberが偶数なら次はusdt、奇数ならnft
            WHEN cycle_number % 2 = 0 THEN 'usdt'
            ELSE 'nft'
        END
    -- cum_usdt >= 1100の場合（HOLDフェーズ）
    ELSE 'nft'  -- 1100以上溜まっているならNFT購入待ち
END;

-- 3. 正しいサイクル処理関数
CREATE OR REPLACE FUNCTION process_daily_yield_with_correct_cycles(
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
    v_user_record RECORD;
    v_user_profit NUMERIC;
    v_company_profit NUMERIC;
    v_base_amount NUMERIC;
    v_new_cum_usdt NUMERIC;
    v_cycles_processed INTEGER;
    v_usdt_to_available NUMERIC;
    v_nft_purchased INTEGER;
    v_remaining NUMERIC;
    v_current_action TEXT;
BEGIN
    -- 利率計算（NFTは1000ドル運用ベース）
    v_after_margin := p_yield_rate * (1 - p_margin_rate / 100);
    v_user_rate := v_after_margin * 0.6;
    
    -- 月末処理の場合は5%ボーナス（仕様にある場合）
    IF p_is_month_end THEN
        v_user_rate := v_user_rate * 1.05;
    END IF;
    
    -- テストモードでない場合のみdaily_yield_logに記録
    IF NOT p_is_test_mode THEN
        INSERT INTO daily_yield_log (
            date, yield_rate, margin_rate, user_rate, is_month_end, created_at
        )
        VALUES (
            p_date, p_yield_rate, p_margin_rate, v_user_rate, p_is_month_end, NOW()
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
            manual_nft_count,
            next_action
        FROM affiliate_cycle 
        WHERE total_nft_count > 0
    LOOP
        v_user_count := v_user_count + 1;
        
        -- 基準金額（NFT数 × 1000運用額）
        v_base_amount := v_user_record.total_nft_count * 1000;
        
        -- ユーザー利益計算
        v_user_profit := v_base_amount * v_user_rate;
        
        -- 会社利益計算
        v_company_profit := v_base_amount * v_after_margin * 0.4;  -- 残り40%
        
        -- 今回の処理金額（前回の残り + 今回の利益）
        v_new_cum_usdt := v_user_record.cum_usdt + v_user_profit;
        v_remaining := v_new_cum_usdt;
        v_usdt_to_available := 0;
        v_nft_purchased := 0;
        v_current_action := v_user_record.next_action;
        
        -- 1100ドルごとの交互サイクル処理
        WHILE v_remaining >= 1100 LOOP
            IF v_current_action = 'usdt' THEN
                -- USDT受取
                v_usdt_to_available := v_usdt_to_available + 1100;
                v_current_action := 'nft';  -- 次はNFT
            ELSE
                -- NFT購入
                v_nft_purchased := v_nft_purchased + 1;
                v_current_action := 'usdt';  -- 次はUSDT
                v_auto_purchases := v_auto_purchases + 1;
            END IF;
            v_remaining := v_remaining - 1100;
            v_cycles_processed := v_cycles_processed + 1;
        END LOOP;
        
        -- 更新処理
        IF NOT p_is_test_mode THEN
            -- affiliate_cycle更新
            UPDATE affiliate_cycle 
            SET 
                cum_usdt = v_remaining,
                available_usdt = available_usdt + v_usdt_to_available,
                total_nft_count = total_nft_count + v_nft_purchased,
                auto_nft_count = auto_nft_count + v_nft_purchased,
                next_action = v_current_action,
                phase = CASE 
                    WHEN v_remaining < 1100 AND v_current_action = 'usdt' THEN 'USDT'
                    ELSE 'HOLD'
                END,
                last_updated = NOW()
            WHERE user_id = v_user_record.user_id;
            
            -- user_daily_profit記録
            INSERT INTO user_daily_profit (
                user_id, date, daily_profit, yield_rate, user_rate, 
                base_amount, personal_profit, referral_profit, phase, created_at
            )
            VALUES (
                v_user_record.user_id, p_date, v_user_profit, p_yield_rate, v_user_rate,
                v_base_amount, v_user_profit, 0, 
                CASE 
                    WHEN v_remaining < 1100 AND v_current_action = 'usdt' THEN 'USDT'
                    ELSE 'HOLD'
                END,
                NOW()
            )
            ON CONFLICT (user_id, date) DO UPDATE SET
                daily_profit = EXCLUDED.daily_profit,
                yield_rate = EXCLUDED.yield_rate,
                user_rate = EXCLUDED.user_rate,
                base_amount = EXCLUDED.base_amount,
                personal_profit = EXCLUDED.personal_profit,
                phase = EXCLUDED.phase,
                created_at = NOW();
            
            -- NFT購入記録
            IF v_nft_purchased > 0 THEN
                INSERT INTO purchases (
                    user_id, nft_quantity, amount_usd, 
                    payment_status, admin_approved, is_auto_purchase, 
                    created_at
                )
                VALUES (
                    v_user_record.user_id, v_nft_purchased, v_nft_purchased * 1100,
                    'completed', true, true,
                    NOW()
                );
            END IF;
        END IF;
        
        v_total_user_profit := v_total_user_profit + v_user_profit;
        v_total_company_profit := v_total_company_profit + v_company_profit;
        v_cycle_updates := v_cycle_updates + v_cycles_processed;
    END LOOP;
    
    -- アフィリエイト報酬の計算と適用
    IF NOT p_is_test_mode THEN
        PERFORM calculate_and_apply_referral_bonuses(p_date);
    END IF;
    
    -- 結果を返す
    RETURN QUERY
    SELECT 
        CASE 
            WHEN p_is_test_mode THEN 'test_success'
            ELSE 'success'
        END,
        v_user_count,
        v_total_user_profit,
        v_total_company_profit,
        v_cycle_updates,
        v_auto_purchases,
        format('処理完了: %s名, 利益配布$%s, サイクル更新%s回, 自動NFT購入%s個',
               v_user_count, 
               round(v_total_user_profit, 2),
               v_cycle_updates,
               v_auto_purchases
        );
END;
$$;

-- 4. CLAUDE.mdの仕様を更新する必要があることを記録
SELECT '交互サイクル処理システムを実装しました' as message,
       '次のアクション: CLAUDE.mdの仕様書を更新してください' as next_step;