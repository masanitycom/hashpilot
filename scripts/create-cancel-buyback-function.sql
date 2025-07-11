/* 買い取り申請キャンセル機能を実装 */

CREATE OR REPLACE FUNCTION cancel_buyback_request(
    p_request_id UUID,
    p_user_id TEXT
)
RETURNS TABLE (
    success BOOLEAN,
    message TEXT
) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_request_status TEXT;
    v_manual_nft_count INTEGER;
    v_auto_nft_count INTEGER;
    v_total_nft_count INTEGER;
BEGIN
    /* 申請の状態とNFT数を確認 */
    SELECT status, manual_nft_count, auto_nft_count, total_nft_count
    INTO v_request_status, v_manual_nft_count, v_auto_nft_count, v_total_nft_count
    FROM buyback_requests 
    WHERE id = p_request_id AND user_id = p_user_id;

    /* 申請が存在しない場合 */
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, '申請が見つかりません';
        RETURN;
    END IF;

    /* 申請中でない場合はキャンセルできない */
    IF v_request_status != 'pending' THEN
        RETURN QUERY SELECT false, '申請中でない申請はキャンセルできません';
        RETURN;
    END IF;

    /* 申請ステータスをキャンセルに変更 */
    UPDATE buyback_requests 
    SET 
        status = 'cancelled',
        processed_at = NOW(),
        processed_by = p_user_id
    WHERE id = p_request_id;

    /* NFT保有数を元に戻す */
    UPDATE affiliate_cycle 
    SET 
        manual_nft_count = manual_nft_count + v_manual_nft_count,
        auto_nft_count = auto_nft_count + v_auto_nft_count,
        total_nft_count = total_nft_count + v_total_nft_count,
        updated_at = NOW()
    WHERE user_id = p_user_id;

    /* システムログを記録 */
    INSERT INTO system_logs (log_type, operation, user_id, message, details)
    VALUES (
        'INFO',
        'buyback_request_cancelled',
        p_user_id,
        'NFT買い取り申請がキャンセルされ、NFT保有数が復元されました',
        jsonb_build_object(
            'request_id', p_request_id,
            'manual_nft_count', v_manual_nft_count,
            'auto_nft_count', v_auto_nft_count,
            'total_nft_count', v_total_nft_count
        )
    );

    RETURN QUERY SELECT true, '買い取り申請をキャンセルしました。NFT保有数が復元されました。';
END;
$$;