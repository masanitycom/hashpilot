-- 紹介報酬の計算ロジックを正しく修正
-- Level1: 直接紹介者の日利の20%
-- Level2: 2段目紹介者の日利の10%  
-- Level3: 3段目紹介者の日利の5%

-- 既存の間違った関数を削除
DROP FUNCTION IF EXISTS process_complete_daily_yield(DATE, NUMERIC, NUMERIC, BOOLEAN);
DROP FUNCTION IF EXISTS process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN);

-- 正しい紹介報酬計算の関数を作成
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
    v_personal_profit NUMERIC;
    v_referral_profit NUMERIC;
    v_total_profit NUMERIC;
    v_company_profit NUMERIC;
    v_base_amount NUMERIC;
    v_nft_count INTEGER;
    v_referral_daily_profit NUMERIC;
BEGIN
    -- 利率計算（マージン後のユーザー利率）
    v_after_margin := p_yield_rate * (1 - p_margin_rate / 100);
    v_user_rate := v_after_margin;
    
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
    
    -- STEP 1: 全ユーザーの個人利益を計算・保存
    FOR v_user_record IN
        SELECT 
            u.user_id,
            u.total_purchases,
            u.referrer_user_id,
            COALESCE(ac.total_nft_count, FLOOR(u.total_purchases / 1100)) as nft_count
        FROM users u
        LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
        WHERE u.total_purchases > 0
        ORDER BY u.user_id
    LOOP
        -- NFT数を確定
        v_nft_count := GREATEST(v_user_record.nft_count, 0);
        
        -- 基準金額（NFT数 × 1100）
        v_base_amount := v_nft_count * 1100;
        
        -- 個人投資分の利益計算
        v_personal_profit := v_base_amount * v_user_rate;
        
        -- まず個人利益のみでuser_daily_profitに保存（後で紹介報酬を追加）
        IF NOT p_is_test_mode THEN
            DELETE FROM user_daily_profit WHERE user_id = v_user_record.user_id AND date = p_date;
            
            INSERT INTO user_daily_profit (
                user_id, date, daily_profit, yield_rate, user_rate, base_amount, 
                personal_profit, referral_profit, phase, created_at
            )
            VALUES (
                v_user_record.user_id, p_date, v_personal_profit, p_yield_rate, v_user_rate, v_base_amount,
                v_personal_profit, 0, 'USDT', NOW()
            );
        END IF;
        
        v_user_count := v_user_count + 1;
        v_total_user_profit := v_total_user_profit + v_personal_profit;
    END LOOP;
    
    -- STEP 2: 紹介報酬を計算・追加
    FOR v_user_record IN
        SELECT 
            u.user_id,
            u.total_purchases,
            u.referrer_user_id
        FROM users u
        WHERE u.total_purchases > 0
        ORDER BY u.user_id
    LOOP
        v_referral_profit := 0;
        
        -- Level1紹介報酬: 直接紹介者の日利の20%
        SELECT COALESCE(SUM(udp.personal_profit * 0.20), 0) INTO v_referral_daily_profit
        FROM users ref_u
        LEFT JOIN user_daily_profit udp ON ref_u.user_id = udp.user_id AND udp.date = p_date
        WHERE ref_u.referrer_user_id = v_user_record.user_id
        AND ref_u.total_purchases > 0;
        
        v_referral_profit := v_referral_profit + v_referral_daily_profit;
        
        -- Level2紹介報酬: 2段目紹介者の日利の10%
        SELECT COALESCE(SUM(udp.personal_profit * 0.10), 0) INTO v_referral_daily_profit
        FROM users ref1_u
        JOIN users ref2_u ON ref2_u.referrer_user_id = ref1_u.user_id
        LEFT JOIN user_daily_profit udp ON ref2_u.user_id = udp.user_id AND udp.date = p_date
        WHERE ref1_u.referrer_user_id = v_user_record.user_id
        AND ref1_u.total_purchases > 0
        AND ref2_u.total_purchases > 0;
        
        v_referral_profit := v_referral_profit + v_referral_daily_profit;
        
        -- Level3紹介報酬: 3段目紹介者の日利の5%
        SELECT COALESCE(SUM(udp.personal_profit * 0.05), 0) INTO v_referral_daily_profit
        FROM users ref1_u
        JOIN users ref2_u ON ref2_u.referrer_user_id = ref1_u.user_id
        JOIN users ref3_u ON ref3_u.referrer_user_id = ref2_u.user_id
        LEFT JOIN user_daily_profit udp ON ref3_u.user_id = udp.user_id AND udp.date = p_date
        WHERE ref1_u.referrer_user_id = v_user_record.user_id
        AND ref1_u.total_purchases > 0
        AND ref2_u.total_purchases > 0
        AND ref3_u.total_purchases > 0;
        
        v_referral_profit := v_referral_profit + v_referral_daily_profit;
        
        -- 総利益 = 個人利益 + 紹介報酬
        SELECT personal_profit INTO v_personal_profit 
        FROM user_daily_profit 
        WHERE user_id = v_user_record.user_id AND date = p_date;
        
        v_total_profit := COALESCE(v_personal_profit, 0) + v_referral_profit;
        
        -- user_daily_profitを更新（紹介報酬を追加）
        IF NOT p_is_test_mode THEN
            UPDATE user_daily_profit 
            SET 
                daily_profit = v_total_profit,
                referral_profit = v_referral_profit,
                updated_at = NOW()
            WHERE user_id = v_user_record.user_id AND date = p_date;
        END IF;
        
        -- 会社利益計算（個人投資分のマージンのみ）
        v_company_profit := COALESCE(v_personal_profit, 0) * p_margin_rate / v_user_rate;
        v_total_company_profit := v_total_company_profit + v_company_profit;
        
        v_cycle_updates := v_cycle_updates + 1;
    END LOOP;
    
    RETURN QUERY SELECT 
        'success'::text,
        v_user_count,
        v_total_user_profit,
        v_total_company_profit,
        v_cycle_updates,
        0, -- auto_nft_purchases（簡素化）
        CASE 
            WHEN p_is_test_mode THEN 
                format('テスト完了: %s名処理予定、個人利益+紹介報酬で総額$%s配布予定', 
                       v_user_count, v_total_user_profit::text)
            ELSE 
                format('処理完了: %s名に総額$%s配布（個人利益+紹介報酬）', 
                       v_user_count, v_total_user_profit::text)
        END;
END;
$$;

-- 完了メッセージ
SELECT '紹介報酬計算を正しく修正しました。Level1-3の日利の20%/10%/5%で計算されます。' as message;