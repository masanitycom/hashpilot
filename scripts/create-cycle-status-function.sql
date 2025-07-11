-- ユーザーのサイクル状況を取得するRPCファンクションを作成

CREATE OR REPLACE FUNCTION get_user_cycle_status(p_user_id TEXT)
RETURNS TABLE (
    next_action TEXT,
    available_usdt NUMERIC,
    total_nft_count INTEGER,
    auto_nft_count INTEGER,
    manual_nft_count INTEGER,
    cum_profit NUMERIC,
    remaining_profit NUMERIC
) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_profit NUMERIC;
    v_available_usdt NUMERIC;
    v_cycles_completed INTEGER;
    v_remaining_profit NUMERIC;
    v_next_action TEXT;
    v_manual_nft_count INTEGER;
    v_auto_nft_count INTEGER;
    v_total_nft_count INTEGER;
BEGIN
    -- ユーザーの累積利益を取得
    SELECT COALESCE(SUM(profit_amount), 0) 
    INTO v_total_profit
    FROM daily_profits 
    WHERE user_id = p_user_id;

    -- ユーザーのNFT数を取得
    SELECT 
        COALESCE(SUM(CASE WHEN purchase_type = 'manual' THEN nft_quantity ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN purchase_type = 'auto' THEN nft_quantity ELSE 0 END), 0)
    INTO v_manual_nft_count, v_auto_nft_count
    FROM purchases 
    WHERE user_id = p_user_id AND admin_approved = true;

    v_total_nft_count := v_manual_nft_count + v_auto_nft_count;

    -- 月末自動出金処理からの利用可能USDT取得
    SELECT COALESCE(available_amount, 0)
    INTO v_available_usdt
    FROM monthly_withdrawals
    WHERE user_id = p_user_id 
    AND status = 'pending'
    ORDER BY created_at DESC 
    LIMIT 1;

    -- 1100ドルサイクルの計算
    v_cycles_completed := FLOOR(v_total_profit / 1100);
    v_remaining_profit := v_total_profit - (v_cycles_completed * 1100);

    -- 次のアクションを決定（交互サイクル）
    -- 奇数サイクル: USDT、偶数サイクル: NFT
    IF v_cycles_completed % 2 = 0 THEN
        v_next_action := 'usdt';
    ELSE
        v_next_action := 'nft';
    END IF;

    -- 結果を返す
    RETURN QUERY SELECT 
        v_next_action,
        v_available_usdt,
        v_total_nft_count,
        v_auto_nft_count,
        v_manual_nft_count,
        v_total_profit,
        v_remaining_profit;
END;
$$;