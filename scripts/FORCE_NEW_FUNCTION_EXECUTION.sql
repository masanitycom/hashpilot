-- 🚨 新しい関数を強制的に実行
-- 2025年7月17日

-- 1. まず古い関数を完全に削除
DROP FUNCTION IF EXISTS process_daily_yield_with_cycles(date,numeric,numeric,boolean,boolean);

-- 2. 紹介報酬計算関数を再作成（念のため）
CREATE OR REPLACE FUNCTION calculate_and_distribute_referral_bonuses(
    p_user_id TEXT,
    p_personal_profit NUMERIC,
    p_date DATE
) RETURNS VOID AS $$
DECLARE
    v_level1_referrer TEXT;
    v_level2_referrer TEXT;
    v_level3_referrer TEXT;
    v_level1_bonus NUMERIC;
    v_level2_bonus NUMERIC;
    v_level3_bonus NUMERIC;
BEGIN
    -- Level1紹介者（直接紹介者）を取得
    SELECT referrer_user_id INTO v_level1_referrer
    FROM users 
    WHERE user_id = p_user_id;
    
    -- Level1報酬計算・配布（20%）
    IF v_level1_referrer IS NOT NULL THEN
        v_level1_bonus := p_personal_profit * 0.20;
        
        -- Level1紹介者の利益に追加
        UPDATE user_daily_profit 
        SET referral_profit = COALESCE(referral_profit, 0) + v_level1_bonus,
            daily_profit = COALESCE(daily_profit, 0) + v_level1_bonus
        WHERE user_id = v_level1_referrer 
        AND date = p_date;
        
        -- Level1紹介者の record が存在しない場合は作成
        IF NOT FOUND THEN
            INSERT INTO user_daily_profit (
                user_id, date, daily_profit, referral_profit, 
                personal_profit, yield_rate, user_rate, base_amount, phase
            ) VALUES (
                v_level1_referrer, p_date, v_level1_bonus, v_level1_bonus,
                0, 0, 0, 0, 'REFERRAL'
            );
        END IF;
        
        -- Level2紹介者を取得
        SELECT referrer_user_id INTO v_level2_referrer
        FROM users 
        WHERE user_id = v_level1_referrer;
        
        -- Level2報酬計算・配布（10%）
        IF v_level2_referrer IS NOT NULL THEN
            v_level2_bonus := p_personal_profit * 0.10;
            
            UPDATE user_daily_profit 
            SET referral_profit = COALESCE(referral_profit, 0) + v_level2_bonus,
                daily_profit = COALESCE(daily_profit, 0) + v_level2_bonus
            WHERE user_id = v_level2_referrer 
            AND date = p_date;
            
            IF NOT FOUND THEN
                INSERT INTO user_daily_profit (
                    user_id, date, daily_profit, referral_profit, 
                    personal_profit, yield_rate, user_rate, base_amount, phase
                ) VALUES (
                    v_level2_referrer, p_date, v_level2_bonus, v_level2_bonus,
                    0, 0, 0, 0, 'REFERRAL'
                );
            END IF;
            
            -- Level3紹介者を取得
            SELECT referrer_user_id INTO v_level3_referrer
            FROM users 
            WHERE user_id = v_level2_referrer;
            
            -- Level3報酬計算・配布（5%）
            IF v_level3_referrer IS NOT NULL THEN
                v_level3_bonus := p_personal_profit * 0.05;
                
                UPDATE user_daily_profit 
                SET referral_profit = COALESCE(referral_profit, 0) + v_level3_bonus,
                    daily_profit = COALESCE(daily_profit, 0) + v_level3_bonus
                WHERE user_id = v_level3_referrer 
                AND date = p_date;
                
                IF NOT FOUND THEN
                    INSERT INTO user_daily_profit (
                        user_id, date, daily_profit, referral_profit, 
                        personal_profit, yield_rate, user_rate, base_amount, phase
                    ) VALUES (
                        v_level3_referrer, p_date, v_level3_bonus, v_level3_bonus,
                        0, 0, 0, 0, 'REFERRAL'
                    );
                END IF;
            END IF;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 3. 新しいprocess_daily_yield_with_cycles関数（紹介報酬付き）
CREATE OR REPLACE FUNCTION process_daily_yield_with_cycles(
    p_date DATE,
    p_yield_rate NUMERIC,
    p_margin_rate NUMERIC,
    p_is_test_mode BOOLEAN DEFAULT true,
    p_is_month_end BOOLEAN DEFAULT false
) RETURNS TABLE (
    processed_users INTEGER,
    total_profit_distributed NUMERIC,
    auto_purchases_created INTEGER,
    processing_time_seconds NUMERIC,
    test_mode BOOLEAN,
    month_end_bonus BOOLEAN
) AS $$
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
        
        -- 月末ボーナス適用後の個人日利計算
        v_daily_profit := v_base_amount * v_user_rate * v_bonus_rate;

        -- 個人日利をuser_daily_profitテーブルに記録
        INSERT INTO user_daily_profit (
            user_id,
            date,
            daily_profit,
            personal_profit,
            referral_profit,
            yield_rate,
            user_rate,
            base_amount,
            phase,
            created_at
        ) VALUES (
            v_user_record.user_id,
            p_date,
            v_daily_profit,
            v_daily_profit,
            0,
            p_yield_rate,
            v_user_rate,
            v_base_amount,
            CASE WHEN v_user_record.next_action = 'usdt' THEN 'USDT' ELSE 'HOLD' END,
            NOW()
        );

        -- 🚨 紹介報酬計算・配布（新機能）
        PERFORM calculate_and_distribute_referral_bonuses(
            v_user_record.user_id,
            v_daily_profit,
            p_date
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

    -- 完了ログ（紹介報酬込み）
    INSERT INTO system_logs (
        log_type,
        operation,
        user_id,
        message,
        details,
        created_at
    ) VALUES (
        'SUCCESS',
        'daily_yield_processing_with_referral',
        NULL,
        FORMAT('日利処理が完了しました（紹介報酬含む）（処理ユーザー数: %s, 総配布額: $%s, 自動購入: %s回）', 
               COALESCE(v_processed_users, 0),
               COALESCE(ROUND(v_total_profit_distributed, 2), 0),
               COALESCE(v_auto_purchases_created, 0)
        ),
        jsonb_build_object(
            'date', p_date,
            'yield_rate', p_yield_rate,
            'margin_rate', p_margin_rate,
            'processed_users', COALESCE(v_processed_users, 0),
            'total_profit_distributed', COALESCE(v_total_profit_distributed, 0),
            'auto_purchases_created', COALESCE(v_auto_purchases_created, 0),
            'processing_time_seconds', COALESCE(v_processing_time, 0),
            'test_mode', p_is_test_mode,
            'month_end_bonus', p_is_month_end,
            'referral_bonuses_enabled', true
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
            'daily_yield_processing_with_referral',
            NULL,
            FORMAT('日利処理（紹介報酬含む）でエラーが発生しました: %s', SQLERRM),
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
$$ LANGUAGE plpgsql;

-- 4. 7/17の日利処理を実行（紹介報酬付き）
SELECT * FROM process_daily_yield_with_cycles(
    '2025-07-17'::date,
    0.0015,      -- 日利率1.5%
    30,          -- マージン率30%
    false,       -- 本番モード
    false        -- 月末処理ではない
);

-- 5. 処理結果確認
SELECT 
    '7/17処理結果' as check_type,
    user_id,
    date,
    daily_profit,
    personal_profit,
    referral_profit,
    base_amount,
    phase
FROM user_daily_profit 
WHERE date = '2025-07-17'
ORDER BY daily_profit DESC;