-- 月末処理にNFT強制購入機能を追加

DROP FUNCTION IF EXISTS process_monthly_auto_withdrawal();

CREATE OR REPLACE FUNCTION process_monthly_auto_withdrawal()
RETURNS TABLE (
    processed_count INTEGER,
    total_amount NUMERIC,
    nft_purchases INTEGER,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_processed_count INTEGER := 0;
    v_total_amount NUMERIC := 0;
    v_nft_purchases INTEGER := 0;
    v_today DATE;
    v_last_day DATE;
    v_user_record RECORD;
BEGIN
    -- 日本時間での現在日付を取得
    v_today := (NOW() AT TIME ZONE 'Asia/Tokyo')::DATE;
    
    -- 当月の最終日を取得
    v_last_day := DATE_TRUNC('month', v_today) + INTERVAL '1 month' - INTERVAL '1 day';
    
    -- 今日が月末でない場合はエラー
    IF v_today != v_last_day THEN
        RETURN QUERY
        SELECT 
            0::INTEGER,
            0::NUMERIC,
            0::INTEGER,
            '本日は月末ではありません。処理をスキップします。'::TEXT;
        RETURN;
    END IF;
    
    -- STEP 1: NFT強制購入処理（cum_usdt >= 2200のユーザー）
    FOR v_user_record IN
        SELECT 
            ac.user_id,
            u.email,
            ac.cum_usdt,
            ac.total_nft_count,
            ac.auto_nft_count
        FROM affiliate_cycle ac
        JOIN users u ON ac.user_id = u.user_id
        WHERE ac.cum_usdt >= 2200
    LOOP
        -- NFT購入数を計算（2200 USDTごとに1つ）
        DECLARE
            v_nft_to_purchase INTEGER;
            v_remaining_usdt NUMERIC;
        BEGIN
            v_nft_to_purchase := FLOOR(v_user_record.cum_usdt / 2200);
            v_remaining_usdt := v_user_record.cum_usdt - (v_nft_to_purchase * 2200);
            
            -- NFT購入処理
            UPDATE affiliate_cycle
            SET 
                total_nft_count = total_nft_count + v_nft_to_purchase,
                auto_nft_count = auto_nft_count + v_nft_to_purchase,
                cum_usdt = v_remaining_usdt,
                available_usdt = available_usdt + (v_nft_to_purchase * 1100), -- 各NFTで1100 USDT受取
                phase = CASE 
                    WHEN v_remaining_usdt >= 1100 THEN 'HOLD'
                    ELSE 'USDT'
                END,
                last_updated = NOW()
            WHERE user_id = v_user_record.user_id;
            
            -- 自動購入履歴に記録
            IF v_nft_to_purchase > 0 THEN
                INSERT INTO auto_purchase_history (
                    user_id,
                    purchase_date,
                    nft_quantity,
                    cum_usdt_before,
                    cum_usdt_after,
                    created_at
                )
                VALUES (
                    v_user_record.user_id,
                    v_today,
                    v_nft_to_purchase,
                    v_user_record.cum_usdt,
                    v_remaining_usdt,
                    NOW()
                );
                
                v_nft_purchases := v_nft_purchases + v_nft_to_purchase;
            END IF;
        END;
    END LOOP;
    
    -- STEP 2: 出金処理（available_usdt >= 100のユーザー）
    FOR v_user_record IN
        SELECT 
            ac.user_id,
            u.email,
            ac.available_usdt,
            uws.withdrawal_address,
            uws.coinw_uid
        FROM affiliate_cycle ac
        JOIN users u ON ac.user_id = u.user_id
        LEFT JOIN user_withdrawal_settings uws ON ac.user_id = uws.user_id
        WHERE ac.available_usdt >= 100  -- 最低出金額100 USDT
        AND NOT EXISTS (
            -- 同月の自動出金申請が既に存在しないかチェック
            SELECT 1 
            FROM withdrawals w 
            WHERE w.user_id = ac.user_id 
            AND w.withdrawal_type = 'monthly_auto'
            AND DATE_TRUNC('month', w.created_at AT TIME ZONE 'Asia/Tokyo') = DATE_TRUNC('month', v_today)
        )
    LOOP
        -- 出金申請を作成
        INSERT INTO withdrawals (
            user_id,
            email,
            amount,
            status,
            withdrawal_type,
            withdrawal_address,
            coinw_uid,
            created_at,
            notes
        )
        VALUES (
            v_user_record.user_id,
            v_user_record.email,
            v_user_record.available_usdt,
            'pending',
            'monthly_auto',
            v_user_record.withdrawal_address,
            v_user_record.coinw_uid,
            NOW(),
            '月末自動出金 - ' || TO_CHAR(v_today, 'YYYY年MM月')
        );
        
        -- available_usdtをリセット
        UPDATE affiliate_cycle
        SET 
            available_usdt = 0,
            last_updated = NOW()
        WHERE user_id = v_user_record.user_id;
        
        v_processed_count := v_processed_count + 1;
        v_total_amount := v_total_amount + v_user_record.available_usdt;
    END LOOP;
    
    -- ログ記録
    BEGIN
        INSERT INTO system_logs (
            log_type,
            message,
            details,
            created_at
        )
        VALUES (
            'monthly_withdrawal',
            '月末処理完了: 出金' || v_processed_count || '件、NFT購入' || v_nft_purchases || '件',
            jsonb_build_object(
                'withdrawal_count', v_processed_count,
                'withdrawal_total', v_total_amount,
                'nft_purchases', v_nft_purchases,
                'process_date', v_today
            ),
            NOW()
        );
    EXCEPTION WHEN undefined_table THEN
        NULL;
    END;
    
    RETURN QUERY
    SELECT 
        v_processed_count,
        v_total_amount,
        v_nft_purchases,
        ('月末処理が完了しました。出金申請: ' || v_processed_count || '件（総額: $' || v_total_amount || '）、NFT自動購入: ' || v_nft_purchases || '件')::TEXT;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION process_monthly_auto_withdrawal() TO authenticated;