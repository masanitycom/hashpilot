-- 自動NFT購入機能の実装
-- 2200 USDT到達時の自動NFT購入処理

-- 1. 自動NFT購入時にpurchasesテーブルにも記録する関数
CREATE OR REPLACE FUNCTION record_auto_nft_purchase(
    p_user_id TEXT,
    p_nft_count INTEGER DEFAULT 1
)
RETURNS TABLE(
    purchase_id UUID,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_purchase_id UUID;
    v_user_exists BOOLEAN;
BEGIN
    -- ユーザー存在確認
    SELECT EXISTS(SELECT 1 FROM users WHERE user_id = p_user_id) INTO v_user_exists;
    
    IF NOT v_user_exists THEN
        RETURN QUERY SELECT 
            NULL::UUID,
            'ユーザーが存在しません'::TEXT;
        RETURN;
    END IF;
    
    -- 自動購入レコードをpurchasesテーブルに挿入
    INSERT INTO purchases (
        id,
        user_id,
        package_type,
        nft_quantity,
        amount_usd,
        payment_method,
        transaction_hash,
        status,
        admin_approved,
        is_auto_purchase,
        created_at,
        updated_at
    )
    VALUES (
        gen_random_uuid(),
        p_user_id,
        'AUTO_CYCLE',
        p_nft_count,
        (p_nft_count * 1100)::TEXT,
        'AUTO_CYCLE_PROFIT',
        'AUTO_' || extract(epoch from now())::TEXT,
        'completed',
        true,
        true,
        NOW(),
        NOW()
    )
    RETURNING id INTO v_purchase_id;
    
    -- usersテーブルのtotal_purchasesを更新
    UPDATE users 
    SET 
        total_purchases = total_purchases + (p_nft_count * 1100),
        updated_at = NOW()
    WHERE user_id = p_user_id;
    
    RETURN QUERY SELECT 
        v_purchase_id,
        FORMAT('自動NFT購入完了: %s NFT ($%s)', p_nft_count, p_nft_count * 1100)::TEXT;
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT 
        NULL::UUID,
        FORMAT('自動NFT購入エラー: %s', SQLERRM)::TEXT;
END;
$$;

-- 2. process_daily_yield_with_cycles関数を更新して自動購入記録を追加
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
BEGIN
    -- 利率計算
    v_after_margin := p_yield_rate * (1 - p_margin_rate / 100);
    v_user_rate := v_after_margin * 0.6;
    
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

-- 3. 自動購入履歴を取得する関数
CREATE OR REPLACE FUNCTION get_auto_purchase_history(
    p_user_id TEXT,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE(
    purchase_id UUID,
    purchase_date TIMESTAMP,
    nft_quantity INTEGER,
    amount_usd TEXT,
    cycle_number INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.created_at,
        p.nft_quantity,
        p.amount_usd,
        COALESCE(ac.cycle_number, 1) as cycle_number
    FROM purchases p
    LEFT JOIN affiliate_cycle ac ON ac.user_id = p.user_id
    WHERE p.user_id = p_user_id 
      AND p.is_auto_purchase = true
      AND p.admin_approved = true
    ORDER BY p.created_at DESC
    LIMIT p_limit;
END;
$$;

-- 実行権限付与
GRANT EXECUTE ON FUNCTION record_auto_nft_purchase(TEXT, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION record_auto_nft_purchase(TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_auto_purchase_history(TEXT, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION get_auto_purchase_history(TEXT, INTEGER) TO authenticated;

-- 4. purchasesテーブルにis_auto_purchaseカラムが存在しない場合は追加
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'purchases' AND column_name = 'is_auto_purchase') THEN
        ALTER TABLE purchases ADD COLUMN is_auto_purchase BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- 5. テスト実行
SELECT 'Auto NFT purchase implementation completed' as status;