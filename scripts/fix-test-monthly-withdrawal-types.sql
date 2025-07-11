-- 月末処理のテスト用関数を修正（型の不一致を解消）

DROP FUNCTION IF EXISTS simulate_monthly_withdrawal();

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
        ac.user_id::TEXT,
        u.email::TEXT,  -- 明示的にTEXTにキャスト
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
        an.user_id::TEXT,
        an.email::TEXT,  -- 明示的にTEXTにキャスト
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

-- 現在の状況を詳しく確認する関数
CREATE OR REPLACE FUNCTION check_cycle_status()
RETURNS TABLE (
    status TEXT,
    user_count BIGINT,
    details TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- cum_usdtが2200以上のユーザー
    RETURN QUERY
    SELECT 
        'cum_usdt >= 2200'::TEXT,
        COUNT(*),
        string_agg(user_id || '($' || ROUND(cum_usdt, 2) || ')', ', ')::TEXT
    FROM affiliate_cycle
    WHERE cum_usdt >= 2200;
    
    -- cum_usdtが1100以上2200未満のユーザー
    RETURN QUERY
    SELECT 
        '1100 <= cum_usdt < 2200'::TEXT,
        COUNT(*),
        string_agg(user_id || '($' || ROUND(cum_usdt, 2) || ')', ', ')::TEXT
    FROM affiliate_cycle
    WHERE cum_usdt >= 1100 AND cum_usdt < 2200;
    
    -- available_usdtが100以上のユーザー
    RETURN QUERY
    SELECT 
        'available_usdt >= 100'::TEXT,
        COUNT(*),
        string_agg(user_id || '($' || ROUND(available_usdt, 2) || ')', ', ')::TEXT
    FROM affiliate_cycle
    WHERE available_usdt >= 100;
    
    -- 全体の統計
    RETURN QUERY
    SELECT 
        '全ユーザー統計'::TEXT,
        COUNT(*),
        ('平均cum_usdt: $' || ROUND(AVG(cum_usdt), 2) || ', 平均available_usdt: $' || ROUND(AVG(available_usdt), 2))::TEXT
    FROM affiliate_cycle
    WHERE total_nft_count > 0;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION simulate_monthly_withdrawal() TO authenticated;
GRANT EXECUTE ON FUNCTION check_cycle_status() TO authenticated;

-- ======================
-- テスト実行
-- ======================

-- 1. 現在のサイクル状況を確認
-- SELECT * FROM check_cycle_status();

-- 2. 月末処理の対象者を確認（修正済み）
-- SELECT * FROM check_monthly_withdrawal_candidates();

-- 3. 月末処理のシミュレーション
-- SELECT * FROM simulate_monthly_withdrawal() ORDER BY action, user_id;