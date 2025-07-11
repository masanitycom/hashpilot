-- 買い取り申請時に即座にNFT保有数を減らす処理を修正

-- 既存の create_buyback_request 関数を修正して、申請時に即座にNFT数を減らす
CREATE OR REPLACE FUNCTION create_buyback_request(
    p_user_id TEXT,
    p_manual_nft_count INTEGER,
    p_auto_nft_count INTEGER,
    p_wallet_address TEXT,
    p_wallet_type TEXT DEFAULT 'USDT-BEP20'
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT,
    total_amount NUMERIC,
    request_id UUID
) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_manual INTEGER;
    v_current_auto INTEGER;
    v_user_profit_total NUMERIC;
    v_manual_buyback NUMERIC;
    v_auto_buyback NUMERIC;
    v_total_buyback NUMERIC;
    v_new_request_id UUID;
BEGIN
    -- 現在のNFT保有数を確認
    SELECT manual_nft_count, auto_nft_count 
    INTO v_current_manual, v_current_auto
    FROM affiliate_cycle 
    WHERE user_id = p_user_id;

    -- NFT保有数の検証
    IF v_current_manual < p_manual_nft_count THEN
        RETURN QUERY SELECT false, '手動NFTの保有数が不足しています', 0::NUMERIC, NULL::UUID;
        RETURN;
    END IF;

    IF v_current_auto < p_auto_nft_count THEN
        RETURN QUERY SELECT false, '自動NFTの保有数が不足しています', 0::NUMERIC, NULL::UUID;
        RETURN;
    END IF;

    -- ユーザーの累積利益を取得
    SELECT COALESCE(SUM(daily_profit), 0) 
    INTO v_user_profit_total
    FROM user_daily_profit 
    WHERE user_id = p_user_id;

    -- 買い取り額計算
    -- 手動NFT: 1000ドル - (累積利益 / 手動NFT数 × 申請数)
    IF p_manual_nft_count > 0 AND v_current_manual > 0 THEN
        v_manual_buyback := GREATEST(0, (1000 * p_manual_nft_count) - (v_user_profit_total / v_current_manual * p_manual_nft_count));
    ELSE
        v_manual_buyback := 0;
    END IF;

    -- 自動NFT: 一律500ドル/枚
    v_auto_buyback := 500 * p_auto_nft_count;
    
    v_total_buyback := v_manual_buyback + v_auto_buyback;

    -- 新しいリクエストIDを生成
    v_new_request_id := gen_random_uuid();

    -- 買い取り申請を記録
    INSERT INTO buyback_requests (
        id,
        user_id,
        request_date,
        manual_nft_count,
        auto_nft_count,
        total_nft_count,
        manual_buyback_amount,
        auto_buyback_amount,
        total_buyback_amount,
        wallet_address,
        wallet_type,
        status
    ) VALUES (
        v_new_request_id,
        p_user_id,
        NOW(),
        p_manual_nft_count,
        p_auto_nft_count,
        p_manual_nft_count + p_auto_nft_count,
        v_manual_buyback,
        v_auto_buyback,
        v_total_buyback,
        p_wallet_address,
        p_wallet_type,
        'pending'
    );

    -- 【重要】申請と同時にNFT保有数を即座に減らす
    UPDATE affiliate_cycle 
    SET 
        manual_nft_count = manual_nft_count - p_manual_nft_count,
        auto_nft_count = auto_nft_count - p_auto_nft_count,
        total_nft_count = total_nft_count - (p_manual_nft_count + p_auto_nft_count),
        updated_at = NOW()
    WHERE user_id = p_user_id;

    -- システムログを記録
    INSERT INTO system_logs (log_type, operation, user_id, message, details)
    VALUES (
        'INFO',
        'buyback_request_created',
        p_user_id,
        'NFT買い取り申請が作成され、NFT保有数が即座に減少されました',
        jsonb_build_object(
            'request_id', v_new_request_id,
            'manual_nft_count', p_manual_nft_count,
            'auto_nft_count', p_auto_nft_count,
            'total_buyback_amount', v_total_buyback,
            'wallet_address', p_wallet_address
        )
    );

    RETURN QUERY SELECT true, '買い取り申請が完了しました', v_total_buyback, v_new_request_id;
END;
$$;