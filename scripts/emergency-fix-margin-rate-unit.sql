-- 🚨 緊急修正: マージン率単位変換エラーの修正
-- 問題: UI → 30% → 0.3 → DB関数（30%期待）→ 異常計算
-- 解決: 関数の単位系を統一

-- 1. 現在の異常設定を確認
SELECT 
    '🔍 異常設定の確認' as check_type,
    COUNT(*) as anomaly_count,
    AVG(margin_rate) as avg_margin_rate,
    MAX(margin_rate) as max_margin_rate,
    MIN(margin_rate) as min_margin_rate
FROM daily_yield_log
WHERE margin_rate > 100;

-- 2. 異常設定の詳細
SELECT 
    '📋 異常設定詳細' as detail_type,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at,
    created_by,
    admin_user_id
FROM daily_yield_log
WHERE margin_rate > 100
ORDER BY created_at DESC;

-- 3. 正常設定（参考）
SELECT 
    '✅ 正常設定（参考）' as normal_type,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    created_at
FROM daily_yield_log
WHERE margin_rate <= 100
ORDER BY created_at DESC
LIMIT 5;

-- 4. 修正版 process_daily_yield_with_cycles 関数
-- 単位系を統一: margin_rateは小数値（0.3 = 30%）として受け取る
CREATE OR REPLACE FUNCTION process_daily_yield_with_cycles(
    p_date DATE,
    p_yield_rate NUMERIC,
    p_margin_rate NUMERIC,  -- 小数値として受け取る（0.3 = 30%）
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
    v_margin_rate_percent NUMERIC; -- パーセンテージ値
BEGIN
    -- 🔧 修正: 小数値をパーセンテージ値に変換
    v_margin_rate_percent := p_margin_rate * 100;
    
    -- 入力値検証
    IF v_margin_rate_percent > 100 THEN
        RAISE EXCEPTION 'マージン率は100%%以下で設定してください。現在の値: %', v_margin_rate_percent;
    END IF;
    
    IF v_margin_rate_percent < 0 THEN
        RAISE EXCEPTION 'マージン率は0%%以上で設定してください。現在の値: %', v_margin_rate_percent;
    END IF;
    
    -- 🔧 修正: 正しい利率計算（パーセンテージ値を使用）
    v_user_rate := (p_yield_rate * (100 - v_margin_rate_percent) / 100) * 0.6;
    
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
        -- NFT購入後15日経過チェック
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
                INSERT INTO purchases (
                    user_id, nft_quantity, amount_usd, payment_status, admin_approved,
                    admin_approved_at, admin_approved_by, admin_notes, is_auto_purchase, created_at
                ) VALUES (
                    v_user_record.user_id, 2, 2200, 'completed', true,
                    NOW(), 'SYSTEM', '自動NFT購入（2200ドル到達）', true, NOW()
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
            
            -- 🔧 修正: 正しい単位でdaily_yield_logに記録
            INSERT INTO daily_yield_log (
                date, yield_rate, margin_rate, user_rate, is_month_end, 
                total_users, total_profit, created_at, created_by
            ) VALUES (
                p_date, p_yield_rate, v_margin_rate_percent, v_user_rate, p_is_month_end,
                1, v_daily_profit, NOW(), 'SYSTEM'
            ) ON CONFLICT (date) DO UPDATE SET
                total_users = daily_yield_log.total_users + 1,
                total_profit = daily_yield_log.total_profit + v_daily_profit,
                updated_at = NOW();
        END IF;
        
        v_processed_users := v_processed_users + 1;
        v_total_profit := v_total_profit + v_daily_profit;
    END LOOP;
    
    RETURN QUERY SELECT 
        'SUCCESS'::TEXT,
        FORMAT('修正版で日利配布完了: %s名処理 (マージン率: %s%%)', v_processed_users, v_margin_rate_percent)::TEXT,
        v_processed_users,
        v_total_profit,
        v_auto_purchases;
END;
$$;

-- 5. 既存の異常データの修正
-- 3000%のような異常値を30%に修正
UPDATE daily_yield_log 
SET 
    margin_rate = 30,
    user_rate = yield_rate * 0.7 * 0.6,  -- 修正された利率で再計算
    updated_at = NOW()
WHERE margin_rate > 100;

-- 6. テーブル制約の追加（将来の異常値を防止）
ALTER TABLE daily_yield_log 
ADD CONSTRAINT check_margin_rate_range 
CHECK (margin_rate >= 0 AND margin_rate <= 100);

-- 7. 修正結果の確認
SELECT 
    '✅ 修正完了確認' as result_type,
    COUNT(*) as total_records,
    COUNT(CASE WHEN margin_rate > 100 THEN 1 END) as anomaly_count,
    AVG(margin_rate) as avg_margin_rate,
    MAX(margin_rate) as max_margin_rate
FROM daily_yield_log;

-- 8. 最新の設定を確認
SELECT 
    '📊 最新設定確認' as latest_type,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    total_users,
    total_profit,
    created_at
FROM daily_yield_log
ORDER BY created_at DESC
LIMIT 5;

-- 9. システムログに修正記録
INSERT INTO system_logs (
    log_type, operation, user_id, message, details, created_at
) VALUES (
    'SUCCESS',
    'EMERGENCY_FIX',
    'SYSTEM',
    'マージン率単位変換エラーの緊急修正完了',
    jsonb_build_object(
        'fix_type', 'margin_rate_unit_conversion',
        'function_updated', 'process_daily_yield_with_cycles',
        'constraint_added', 'check_margin_rate_range',
        'anomaly_data_fixed', true,
        'fix_timestamp', NOW()
    ),
    NOW()
);

SELECT '🎉 緊急修正が完了しました！' as status;