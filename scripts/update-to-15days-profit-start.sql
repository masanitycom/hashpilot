-- NFT承認後15日後から運用開始への変更

-- 1. 現在の設定確認
SELECT 
    '📅 運用開始ルール変更: 翌日 → 15日後' as update_info,
    '承認日 + 15日後から日利開始' as new_rule;

-- 2. 日利計算関数を修正（15日後開始）
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
        -- 🔥 変更: 15日後チェック（翌日から15日後に変更）
        SELECT MAX(admin_approved_at::date) INTO v_latest_purchase_date
        FROM purchases 
        WHERE user_id = v_user_record.user_id 
        AND admin_approved = true;
        
        -- 承認日から15日経過していない場合はスキップ
        IF v_latest_purchase_date IS NOT NULL AND v_latest_purchase_date + INTERVAL '14 days' >= p_date THEN
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
                -- 🔥 購入記録に承認日として現在日を記録
                INSERT INTO purchases (
                    user_id,
                    nft_quantity,
                    amount_usd,
                    payment_status,
                    admin_approved,
                    admin_approved_at,
                    admin_approved_by,
                    admin_notes,
                    is_auto_purchase,
                    created_at
                ) VALUES (
                    v_user_record.user_id,
                    2,
                    2200,
                    'completed',
                    true,
                    NOW(), -- 現在時刻を承認日として記録
                    'SYSTEM',
                    '自動NFT購入（2200ドル到達）',
                    true,
                    NOW()
                );
                
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
        FORMAT('15日後開始ルールで日利配布完了: %s名処理', v_processed_users)::TEXT,
        v_processed_users,
        v_total_profit,
        v_auto_purchases;
END;
$$;

-- 3. テスト用関数も更新
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
        
        -- 🔥 購入後15日経過チェック
        IF v_latest_purchase_date IS NULL OR v_latest_purchase_date + INTERVAL '14 days' >= p_date THEN
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
        FORMAT('15日後開始ルールで%s名に日利配布完了', v_processed_users)::TEXT,
        v_processed_users,
        v_total_profit;
END;
$$;

-- 4. 確認用クエリ
SELECT 
    '✅ 修正完了確認' as status,
    '承認日 + 15日後から日利開始' as new_rule,
    '自動購入NFTも15日後から開始' as auto_nft_rule;

-- 5. 影響を受けるユーザーの確認
SELECT 
    u.user_id,
    u.email,
    MAX(p.admin_approved_at::date) as latest_purchase,
    MAX(p.admin_approved_at::date) + INTERVAL '15 days' as profit_start_date,
    CASE 
        WHEN MAX(p.admin_approved_at::date) + INTERVAL '14 days' >= CURRENT_DATE THEN '待機中'
        ELSE '運用中'
    END as status
FROM users u
JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
JOIN affiliate_cycle ac ON u.user_id = ac.user_id AND ac.total_nft_count > 0
GROUP BY u.user_id, u.email
ORDER BY latest_purchase DESC
LIMIT 10;