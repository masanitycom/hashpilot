-- NFT買い取り申請用の関数を作成

-- 1. 買い取り申請履歴を取得する関数
CREATE OR REPLACE FUNCTION get_buyback_requests(p_user_id TEXT)
RETURNS TABLE (
    id UUID,
    user_id TEXT,
    email TEXT,
    request_date TIMESTAMP WITH TIME ZONE,
    manual_nft_count INTEGER,
    auto_nft_count INTEGER,
    total_nft_count INTEGER,
    manual_buyback_amount NUMERIC,
    auto_buyback_amount NUMERIC,
    total_buyback_amount NUMERIC,
    wallet_address TEXT,
    wallet_type TEXT,
    status TEXT,
    processed_by TEXT,
    processed_at TIMESTAMP WITH TIME ZONE,
    transaction_hash TEXT,
    created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        br.id,
        br.user_id,
        br.email,
        br.request_date,
        br.manual_nft_count,
        br.auto_nft_count,
        br.total_nft_count,
        br.manual_buyback_amount,
        br.auto_buyback_amount,
        br.total_buyback_amount,
        br.wallet_address,
        br.wallet_type,
        br.status,
        br.processed_by,
        br.processed_at,
        br.transaction_hash,
        br.created_at
    FROM buyback_requests br
    WHERE br.user_id = p_user_id
    ORDER BY br.created_at DESC;
END;
$$;

-- 2. 買い取り申請を作成する関数
CREATE OR REPLACE FUNCTION create_buyback_request(
    p_user_id TEXT,
    p_manual_nft_count INTEGER,
    p_auto_nft_count INTEGER,
    p_wallet_address TEXT,
    p_wallet_type TEXT
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    request_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_email TEXT;
    v_user_profit NUMERIC;
    v_manual_amount NUMERIC;
    v_auto_amount NUMERIC;
    v_total_amount NUMERIC;
    v_request_id UUID;
    v_cycle_data RECORD;
BEGIN
    -- ユーザー情報を取得
    SELECT email INTO v_user_email
    FROM users
    WHERE user_id = p_user_id;
    
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT 
            FALSE,
            'ユーザーが見つかりません'::TEXT,
            NULL::UUID;
        RETURN;
    END IF;
    
    -- affiliate_cycleから現在のNFT数を取得
    SELECT * INTO v_cycle_data
    FROM affiliate_cycle
    WHERE user_id = p_user_id;
    
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT 
            FALSE,
            'NFT保有情報が見つかりません'::TEXT,
            NULL::UUID;
        RETURN;
    END IF;
    
    -- NFT数のチェック
    IF p_manual_nft_count > v_cycle_data.manual_nft_count THEN
        RETURN QUERY
        SELECT 
            FALSE,
            '手動購入NFT数が保有数を超えています'::TEXT,
            NULL::UUID;
        RETURN;
    END IF;
    
    IF p_auto_nft_count > v_cycle_data.auto_nft_count THEN
        RETURN QUERY
        SELECT 
            FALSE,
            '自動購入NFT数が保有数を超えています'::TEXT,
            NULL::UUID;
        RETURN;
    END IF;
    
    -- ユーザーの累計利益を計算
    SELECT COALESCE(SUM(daily_profit), 0) INTO v_user_profit
    FROM user_daily_profit
    WHERE user_id = p_user_id;
    
    -- 買い取り金額を計算
    -- 手動購入: 1000ドル - 利益額
    -- 自動購入: 500ドル固定
    v_manual_amount := GREATEST(0, (1000 * p_manual_nft_count) - v_user_profit);
    v_auto_amount := 500 * p_auto_nft_count;
    v_total_amount := v_manual_amount + v_auto_amount;
    
    -- 買い取り申請を作成
    INSERT INTO buyback_requests (
        user_id,
        email,
        request_date,
        manual_nft_count,
        auto_nft_count,
        total_nft_count,
        manual_buyback_amount,
        auto_buyback_amount,
        total_buyback_amount,
        wallet_address,
        wallet_type,
        status,
        created_at
    )
    VALUES (
        p_user_id,
        v_user_email,
        NOW(),
        p_manual_nft_count,
        p_auto_nft_count,
        p_manual_nft_count + p_auto_nft_count,
        v_manual_amount,
        v_auto_amount,
        v_total_amount,
        p_wallet_address,
        p_wallet_type,
        'pending',
        NOW()
    )
    RETURNING id INTO v_request_id;
    
    -- NFT数を減らす
    UPDATE affiliate_cycle
    SET 
        manual_nft_count = manual_nft_count - p_manual_nft_count,
        auto_nft_count = auto_nft_count - p_auto_nft_count,
        total_nft_count = total_nft_count - (p_manual_nft_count + p_auto_nft_count),
        last_updated = NOW()
    WHERE user_id = p_user_id;
    
    -- ログ記録
    INSERT INTO system_logs (
        log_type,
        operation,
        user_id,
        message,
        details,
        created_at
    )
    VALUES (
        'buyback_request',
        'create',
        p_user_id,
        'NFT買い取り申請作成',
        jsonb_build_object(
            'request_id', v_request_id,
            'manual_nft', p_manual_nft_count,
            'auto_nft', p_auto_nft_count,
            'total_amount', v_total_amount
        ),
        NOW()
    );
    
    RETURN QUERY
    SELECT 
        TRUE,
        ('買い取り申請が作成されました。申請ID: ' || v_request_id::TEXT)::TEXT,
        v_request_id;
END;
$$;

-- 3. 管理者用：すべての買い取り申請を取得
CREATE OR REPLACE FUNCTION get_all_buyback_requests(
    p_status TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    user_id TEXT,
    email TEXT,
    request_date TIMESTAMP WITH TIME ZONE,
    manual_nft_count INTEGER,
    auto_nft_count INTEGER,
    total_nft_count INTEGER,
    manual_buyback_amount NUMERIC,
    auto_buyback_amount NUMERIC,
    total_buyback_amount NUMERIC,
    wallet_address TEXT,
    wallet_type TEXT,
    status TEXT,
    processed_by TEXT,
    processed_at TIMESTAMP WITH TIME ZONE,
    transaction_hash TEXT,
    created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        br.id,
        br.user_id,
        br.email,
        br.request_date,
        br.manual_nft_count,
        br.auto_nft_count,
        br.total_nft_count,
        br.manual_buyback_amount,
        br.auto_buyback_amount,
        br.total_buyback_amount,
        br.wallet_address,
        br.wallet_type,
        br.status,
        br.processed_by,
        br.processed_at,
        br.transaction_hash,
        br.created_at
    FROM buyback_requests br
    WHERE p_status IS NULL OR br.status = p_status
    ORDER BY br.created_at DESC;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION get_buyback_requests(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION create_buyback_request(TEXT, INTEGER, INTEGER, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_buyback_requests(TEXT) TO authenticated;