-- 月末処理のテスト用関数とシミュレーション

-- 1. 月末処理のシミュレーション関数（実際のデータは変更しない）
CREATE OR REPLACE FUNCTION simulate_monthly_withdrawal()
RETURNS TABLE (
    user_id TEXT,
    email TEXT,
    action TEXT,
    cum_usdt_before NUMERIC,
    cum_usdt_after NUMERIC,
    available_usdt_before NUMERIC,
    available_usdt_after NUMERIC,
    nft_to_purchase INTEGER,
    withdrawal_amount NUMERIC,
    notes TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- NFT強制購入のシミュレーション
    RETURN QUERY
    SELECT 
        ac.user_id,
        u.email,
        'NFT自動購入'::TEXT as action,
        ac.cum_usdt as cum_usdt_before,
        ac.cum_usdt - (FLOOR(ac.cum_usdt / 2200) * 2200) as cum_usdt_after,
        ac.available_usdt as available_usdt_before,
        ac.available_usdt + (FLOOR(ac.cum_usdt / 2200) * 1100) as available_usdt_after,
        FLOOR(ac.cum_usdt / 2200)::INTEGER as nft_to_purchase,
        0::NUMERIC as withdrawal_amount,
        ('NFT ' || FLOOR(ac.cum_usdt / 2200) || '個購入')::TEXT as notes
    FROM affiliate_cycle ac
    JOIN users u ON ac.user_id = u.user_id
    WHERE ac.cum_usdt >= 2200;
    
    -- 出金処理のシミュレーション（NFT購入後の状態を考慮）
    RETURN QUERY
    WITH after_nft AS (
        SELECT 
            ac.user_id,
            u.email,
            CASE 
                WHEN ac.cum_usdt >= 2200 THEN ac.available_usdt + (FLOOR(ac.cum_usdt / 2200) * 1100)
                ELSE ac.available_usdt
            END as new_available_usdt
        FROM affiliate_cycle ac
        JOIN users u ON ac.user_id = u.user_id
    )
    SELECT 
        an.user_id,
        an.email,
        '自動出金'::TEXT as action,
        0::NUMERIC as cum_usdt_before,
        0::NUMERIC as cum_usdt_after,
        an.new_available_usdt as available_usdt_before,
        0::NUMERIC as available_usdt_after,
        0::INTEGER as nft_to_purchase,
        an.new_available_usdt as withdrawal_amount,
        ('$' || an.new_available_usdt || ' 出金申請')::TEXT as notes
    FROM after_nft an
    WHERE an.new_available_usdt >= 100
    AND NOT EXISTS (
        SELECT 1 
        FROM withdrawals w 
        WHERE w.user_id = an.user_id 
        AND w.withdrawal_type = 'monthly_auto'
        AND DATE_TRUNC('month', w.created_at AT TIME ZONE 'Asia/Tokyo') = DATE_TRUNC('month', (NOW() AT TIME ZONE 'Asia/Tokyo')::DATE)
    );
END;
$$;

-- 2. 現在の状態を確認
CREATE OR REPLACE FUNCTION check_monthly_withdrawal_candidates()
RETURNS TABLE (
    category TEXT,
    user_count BIGINT,
    total_amount NUMERIC,
    details TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- NFT購入対象者
    RETURN QUERY
    SELECT 
        'NFT自動購入対象'::TEXT,
        COUNT(*),
        SUM(FLOOR(cum_usdt / 2200) * 2200),
        ('平均cum_usdt: $' || ROUND(AVG(cum_usdt), 2))::TEXT
    FROM affiliate_cycle
    WHERE cum_usdt >= 2200;
    
    -- 出金対象者（NFT購入前）
    RETURN QUERY
    SELECT 
        '出金対象（現在）'::TEXT,
        COUNT(*),
        SUM(available_usdt),
        ('平均available_usdt: $' || ROUND(AVG(available_usdt), 2))::TEXT
    FROM affiliate_cycle
    WHERE available_usdt >= 100;
    
    -- 出金対象者（NFT購入後の予測）
    RETURN QUERY
    WITH after_nft AS (
        SELECT 
            user_id,
            CASE 
                WHEN cum_usdt >= 2200 THEN available_usdt + (FLOOR(cum_usdt / 2200) * 1100)
                ELSE available_usdt
            END as new_available_usdt
        FROM affiliate_cycle
    )
    SELECT 
        '出金対象（NFT購入後）'::TEXT,
        COUNT(*),
        SUM(new_available_usdt),
        ('平均available_usdt: $' || ROUND(AVG(new_available_usdt), 2))::TEXT
    FROM after_nft
    WHERE new_available_usdt >= 100;
END;
$$;

-- 3. 特定ユーザーの月末処理シミュレーション
CREATE OR REPLACE FUNCTION simulate_user_monthly_process(p_user_id TEXT)
RETURNS TABLE (
    step TEXT,
    field TEXT,
    before_value NUMERIC,
    after_value NUMERIC,
    change NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_record RECORD;
    v_nft_to_buy INTEGER;
    v_cum_after NUMERIC;
    v_available_after NUMERIC;
BEGIN
    -- 現在の状態を取得
    SELECT 
        ac.*,
        u.email
    INTO v_record
    FROM affiliate_cycle ac
    JOIN users u ON ac.user_id = u.user_id
    WHERE ac.user_id = p_user_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ユーザー % が見つかりません', p_user_id;
    END IF;
    
    -- NFT購入計算
    v_nft_to_buy := FLOOR(v_record.cum_usdt / 2200);
    v_cum_after := v_record.cum_usdt - (v_nft_to_buy * 2200);
    v_available_after := v_record.available_usdt + (v_nft_to_buy * 1100);
    
    -- 結果を返す
    RETURN QUERY
    SELECT 
        'NFT購入'::TEXT,
        'cum_usdt'::TEXT,
        v_record.cum_usdt,
        v_cum_after,
        v_cum_after - v_record.cum_usdt;
        
    RETURN QUERY
    SELECT 
        'NFT購入'::TEXT,
        'available_usdt'::TEXT,
        v_record.available_usdt,
        v_available_after,
        v_available_after - v_record.available_usdt;
        
    RETURN QUERY
    SELECT 
        'NFT購入'::TEXT,
        'total_nft_count'::TEXT,
        v_record.total_nft_count::NUMERIC,
        (v_record.total_nft_count + v_nft_to_buy)::NUMERIC,
        v_nft_to_buy::NUMERIC;
        
    RETURN QUERY
    SELECT 
        '出金'::TEXT,
        'available_usdt'::TEXT,
        v_available_after,
        CASE WHEN v_available_after >= 100 THEN 0::NUMERIC ELSE v_available_after END,
        CASE WHEN v_available_after >= 100 THEN -v_available_after ELSE 0::NUMERIC END;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION simulate_monthly_withdrawal() TO authenticated;
GRANT EXECUTE ON FUNCTION check_monthly_withdrawal_candidates() TO authenticated;
GRANT EXECUTE ON FUNCTION simulate_user_monthly_process(TEXT) TO authenticated;

-- ======================
-- テスト実行例
-- ======================

-- 1. 月末処理の対象者を確認
SELECT * FROM check_monthly_withdrawal_candidates();

-- 2. 月末処理のシミュレーション（全ユーザー）
SELECT * FROM simulate_monthly_withdrawal() ORDER BY action, user_id;

-- 3. 特定ユーザーの月末処理シミュレーション（例: 7A9637）
-- SELECT * FROM simulate_user_monthly_process('7A9637');

-- 4. 実際の月末処理を実行（本番）
-- SELECT * FROM process_monthly_auto_withdrawal();