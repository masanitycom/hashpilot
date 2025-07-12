-- NFT購入翌日から日利開始の実装

-- 1. 現在の問題を確認
SELECT 
    '🔍 現在の問題確認:' as info,
    u.user_id,
    u.email,
    p.admin_approved_at::date as purchase_date,
    udp.date as profit_date,
    udp.daily_profit,
    '購入当日に日利発生' as issue
FROM users u
JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE p.admin_approved_at::date = udp.date
ORDER BY p.admin_approved_at DESC
LIMIT 5;

-- 2. 日利計算関数を修正（翌日開始）
CREATE OR REPLACE FUNCTION calculate_daily_profit_with_purchase_date_check(
    p_date DATE,
    p_yield_rate NUMERIC,
    p_margin_rate NUMERIC,
    p_is_test_mode BOOLEAN DEFAULT true
)
RETURNS TABLE (
    status TEXT,
    message TEXT,
    processed_users INTEGER,
    total_profit NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_processed_users INTEGER := 0;
    v_total_profit NUMERIC := 0;
    v_user_record RECORD;
    v_user_rate NUMERIC;
    v_daily_profit NUMERIC;
    v_base_amount NUMERIC;
    v_latest_purchase_date DATE;
BEGIN
    -- ユーザーごとに処理
    FOR v_user_record IN
        SELECT 
            ac.user_id,
            ac.total_nft_count,
            ac.phase
        FROM affiliate_cycle ac
        WHERE ac.total_nft_count > 0
    LOOP
        -- 最新の承認済み購入日を取得
        SELECT MAX(admin_approved_at::date) INTO v_latest_purchase_date
        FROM purchases 
        WHERE user_id = v_user_record.user_id 
        AND admin_approved = true;
        
        -- 購入翌日以降のみ日利を付与
        IF v_latest_purchase_date IS NULL OR v_latest_purchase_date >= p_date THEN
            CONTINUE; -- スキップ
        END IF;
        
        -- 利率計算
        v_user_rate := (p_yield_rate * (100 - p_margin_rate) / 100) * 0.6;
        
        -- 運用額計算（NFT数 × 1000ドル）
        v_base_amount := v_user_record.total_nft_count * 1000;
        
        -- 日利計算
        v_daily_profit := v_base_amount * v_user_rate / 100;
        
        -- テストモードでない場合のみ実際に記録
        IF NOT p_is_test_mode THEN
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
                v_user_record.phase,
                NOW()
            );
        END IF;
        
        v_processed_users := v_processed_users + 1;
        v_total_profit := v_total_profit + v_daily_profit;
    END LOOP;
    
    RETURN QUERY SELECT 
        'SUCCESS'::TEXT,
        FORMAT('翌日開始ルールで%s名に日利配布完了', v_processed_users)::TEXT,
        v_processed_users,
        v_total_profit;
END;
$$;

-- 3. 既存の日利関数を修正
CREATE OR REPLACE FUNCTION process_daily_yield_with_cycles(
    p_date DATE,
    p_yield_rate NUMERIC,
    p_margin_rate NUMERIC,
    p_is_test_mode BOOLEAN DEFAULT true,
    p_is_month_end BOOLEAN DEFAULT false
)
RETURNS TABLE (
    status TEXT,
    message TEXT,
    total_users INTEGER,
    total_profit NUMERIC,
    auto_purchases INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_record RECORD;
    v_user_rate NUMERIC;
    v_daily_profit NUMERIC;
    v_base_amount NUMERIC;
    v_processed_users INTEGER := 0;
    v_total_profit NUMERIC := 0;
    v_auto_purchases INTEGER := 0;
    v_latest_purchase_date DATE;
BEGIN
    -- 利率計算
    v_user_rate := (p_yield_rate * (100 - p_margin_rate) / 100) * 0.6;
    
    -- 月末ボーナス
    IF p_is_month_end THEN
        v_user_rate := v_user_rate * 1.05; -- 5%ボーナス
    END IF;
    
    -- ユーザーごとに処理
    FOR v_user_record IN
        SELECT 
            ac.user_id,
            ac.total_nft_count,
            ac.phase,
            ac.cum_usdt,
            ac.available_usdt
        FROM affiliate_cycle ac
        WHERE ac.total_nft_count > 0
    LOOP
        -- 🔥 NEW: 購入翌日チェック
        SELECT MAX(admin_approved_at::date) INTO v_latest_purchase_date
        FROM purchases 
        WHERE user_id = v_user_record.user_id 
        AND admin_approved = true;
        
        -- 購入当日は日利付与しない
        IF v_latest_purchase_date IS NOT NULL AND v_latest_purchase_date >= p_date THEN
            CONTINUE;
        END IF;
        
        -- 運用額計算
        v_base_amount := v_user_record.total_nft_count * 1000;
        v_daily_profit := v_base_amount * v_user_rate / 100;
        
        -- テストモードでない場合のみ実際に記録
        IF NOT p_is_test_mode THEN
            -- 日利記録
            INSERT INTO user_daily_profit (
                user_id, date, daily_profit, yield_rate, user_rate, base_amount, phase
            ) VALUES (
                v_user_record.user_id, p_date, v_daily_profit, p_yield_rate, v_user_rate, v_base_amount, v_user_record.phase
            );
            
            -- サイクル処理（利益累積）
            UPDATE affiliate_cycle 
            SET 
                cum_usdt = cum_usdt + v_daily_profit,
                available_usdt = available_usdt + v_daily_profit,
                updated_at = NOW()
            WHERE user_id = v_user_record.user_id;
            
            -- 自動NFT購入チェック（2200ドル到達）
            IF (v_user_record.cum_usdt + v_daily_profit) >= 2200 THEN
                -- 自動NFT購入処理
                UPDATE affiliate_cycle 
                SET 
                    total_nft_count = total_nft_count + 2,
                    auto_nft_count = auto_nft_count + 2,
                    cum_usdt = (cum_usdt + v_daily_profit) - 2200,
                    available_usdt = (available_usdt + v_daily_profit) - 2200
                WHERE user_id = v_user_record.user_id;
                
                v_auto_purchases := v_auto_purchases + 1;
            END IF;
        END IF;
        
        v_processed_users := v_processed_users + 1;
        v_total_profit := v_total_profit + v_daily_profit;
    END LOOP;
    
    RETURN QUERY SELECT 
        'SUCCESS'::TEXT,
        FORMAT('翌日開始ルールで日利配布完了: %s名処理', v_processed_users)::TEXT,
        v_processed_users,
        v_total_profit,
        v_auto_purchases;
END;
$$;

-- 4. テスト実行
SELECT * FROM calculate_daily_profit_with_purchase_date_check(
    CURRENT_DATE, 
    1.5, 
    30, 
    true -- テストモード
);

-- 5. 確認用クエリ
SELECT 
    '✅ 修正後の動作確認:' as info,
    '購入当日のユーザーは日利対象外になります' as note;