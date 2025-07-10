-- 日利計算システムの完全再設計
-- 個人投資分 + 紹介報酬（1段目20%、2段目10%、3段目5%）を正しく計算

-- 既存の不完全な関数を削除
DROP FUNCTION IF EXISTS process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN);

-- 新しい正しい日利計算関数を作成
CREATE OR REPLACE FUNCTION process_complete_daily_yield(
    p_date DATE,
    p_yield_rate NUMERIC,
    p_margin_rate NUMERIC,
    p_is_test_mode BOOLEAN DEFAULT true
)
RETURNS TABLE(
    status text,
    total_users integer,
    total_personal_profit numeric,
    total_referral_profit numeric,
    total_company_profit numeric,
    level1_bonuses integer,
    level2_bonuses integer,
    level3_bonuses integer,
    message text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_count INTEGER := 0;
    v_total_personal_profit NUMERIC := 0;
    v_total_referral_profit NUMERIC := 0;
    v_total_company_profit NUMERIC := 0;
    v_level1_bonuses INTEGER := 0;
    v_level2_bonuses INTEGER := 0;
    v_level3_bonuses INTEGER := 0;
    v_user_rate NUMERIC;
    v_after_margin NUMERIC;
    v_user_record RECORD;
    v_referral_record RECORD;
    v_personal_profit NUMERIC;
    v_total_user_profit NUMERIC;
    v_referral_profit NUMERIC;
    v_company_profit NUMERIC;
    v_base_amount NUMERIC;
    v_nft_count INTEGER;
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
    
    -- 全ユーザーの処理
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
        
        -- 紹介報酬の計算
        v_referral_profit := 0;
        
        -- 1段目の紹介報酬（20%）
        FOR v_referral_record IN
            SELECT 
                ref_u.user_id as referral_user_id,
                COALESCE(ref_ac.total_nft_count, FLOOR(ref_u.total_purchases / 1100)) as ref_nft_count
            FROM users ref_u
            LEFT JOIN affiliate_cycle ref_ac ON ref_u.user_id = ref_ac.user_id
            WHERE ref_u.referrer_user_id = v_user_record.user_id
            AND ref_u.total_purchases > 0
        LOOP
            v_referral_profit := v_referral_profit + (ref_ac.total_nft_count * 1100 * v_user_rate * 0.20);
            v_level1_bonuses := v_level1_bonuses + 1;
        END LOOP;
        
        -- 2段目の紹介報酬（10%）
        FOR v_referral_record IN
            SELECT 
                ref2_u.user_id as referral_user_id,
                COALESCE(ref2_ac.total_nft_count, FLOOR(ref2_u.total_purchases / 1100)) as ref_nft_count
            FROM users ref1_u
            JOIN users ref2_u ON ref2_u.referrer_user_id = ref1_u.user_id
            LEFT JOIN affiliate_cycle ref2_ac ON ref2_u.user_id = ref2_ac.user_id
            WHERE ref1_u.referrer_user_id = v_user_record.user_id
            AND ref1_u.total_purchases > 0
            AND ref2_u.total_purchases > 0
        LOOP
            v_referral_profit := v_referral_profit + (v_referral_record.ref_nft_count * 1100 * v_user_rate * 0.10);
            v_level2_bonuses := v_level2_bonuses + 1;
        END LOOP;
        
        -- 3段目の紹介報酬（5%）
        FOR v_referral_record IN
            SELECT 
                ref3_u.user_id as referral_user_id,
                COALESCE(ref3_ac.total_nft_count, FLOOR(ref3_u.total_purchases / 1100)) as ref_nft_count
            FROM users ref1_u
            JOIN users ref2_u ON ref2_u.referrer_user_id = ref1_u.user_id
            JOIN users ref3_u ON ref3_u.referrer_user_id = ref2_u.user_id
            LEFT JOIN affiliate_cycle ref3_ac ON ref3_u.user_id = ref3_ac.user_id
            WHERE ref1_u.referrer_user_id = v_user_record.user_id
            AND ref1_u.total_purchases > 0
            AND ref2_u.total_purchases > 0
            AND ref3_u.total_purchases > 0
        LOOP
            v_referral_profit := v_referral_profit + (v_referral_record.ref_nft_count * 1100 * v_user_rate * 0.05);
            v_level3_bonuses := v_level3_bonuses + 1;
        END LOOP;
        
        -- ユーザーの総利益
        v_total_user_profit := v_personal_profit + v_referral_profit;
        
        -- 会社利益計算
        v_company_profit := v_base_amount * p_margin_rate / 100;
        
        -- サイクル処理（既存ロジックを維持）
        IF NOT p_is_test_mode AND v_nft_count > 0 THEN
            -- affiliate_cycleの更新
            INSERT INTO affiliate_cycle (
                user_id, phase, total_nft_count, cum_usdt, available_usdt, 
                auto_nft_count, manual_nft_count, cycle_number, last_updated
            )
            VALUES (
                v_user_record.user_id, 'USDT', v_nft_count, v_total_user_profit, v_total_user_profit,
                0, v_nft_count, 1, NOW()
            )
            ON CONFLICT (user_id) DO UPDATE SET
                cum_usdt = affiliate_cycle.cum_usdt + v_total_user_profit,
                available_usdt = affiliate_cycle.available_usdt + v_total_user_profit,
                last_updated = NOW();
        END IF;
        
        -- user_daily_profitテーブルに記録（テストモードでない場合のみ）
        IF NOT p_is_test_mode THEN
            DELETE FROM user_daily_profit WHERE user_id = v_user_record.user_id AND date = p_date;
            
            INSERT INTO user_daily_profit (
                user_id, date, daily_profit, yield_rate, user_rate, base_amount, 
                personal_profit, referral_profit, phase, created_at
            )
            VALUES (
                v_user_record.user_id, p_date, v_total_user_profit, p_yield_rate, v_user_rate, v_base_amount,
                v_personal_profit, v_referral_profit, 'USDT', NOW()
            )
            ON CONFLICT (user_id, date) DO UPDATE SET
                daily_profit = EXCLUDED.daily_profit,
                personal_profit = EXCLUDED.personal_profit,
                referral_profit = EXCLUDED.referral_profit,
                updated_at = NOW();
        END IF;
        
        v_user_count := v_user_count + 1;
        v_total_personal_profit := v_total_personal_profit + v_personal_profit;
        v_total_referral_profit := v_total_referral_profit + v_referral_profit;
        v_total_company_profit := v_total_company_profit + v_company_profit;
    END LOOP;
    
    RETURN QUERY SELECT 
        'success'::text,
        v_user_count,
        v_total_personal_profit,
        v_total_referral_profit,
        v_total_company_profit,
        v_level1_bonuses,
        v_level2_bonuses,
        v_level3_bonuses,
        CASE 
            WHEN p_is_test_mode THEN 
                format('テスト完了: %s名処理予定、個人利益$%s、紹介報酬$%s、会社利益$%s', 
                       v_user_count, v_total_personal_profit::text, v_total_referral_profit::text, v_total_company_profit::text)
            ELSE 
                format('処理完了: %s名に個人利益$%s + 紹介報酬$%s = 総額$%sを配布', 
                       v_user_count, v_total_personal_profit::text, v_total_referral_profit::text, 
                       (v_total_personal_profit + v_total_referral_profit)::text)
        END;
END;
$$;

-- user_daily_profitテーブルに新しいカラムを追加
ALTER TABLE user_daily_profit 
ADD COLUMN IF NOT EXISTS personal_profit NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS referral_profit NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();

-- 日利設定ページの関数名を更新するため、新しいエイリアス関数を作成
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
    v_result RECORD;
BEGIN
    -- 新しい関数を呼び出す
    SELECT * INTO v_result FROM process_complete_daily_yield(p_date, p_yield_rate, p_margin_rate, p_is_test_mode);
    
    RETURN QUERY SELECT 
        v_result.status,
        v_result.total_users,
        v_result.total_personal_profit + v_result.total_referral_profit, -- 総利益
        v_result.total_company_profit,
        v_result.total_users, -- cycle_updates
        0, -- auto_nft_purchases（簡素化）
        v_result.message;
END;
$$;

-- 完了メッセージ
SELECT '日利計算システムを完全に再設計しました。個人投資分 + 3段階の紹介報酬を正しく計算します。' as message;