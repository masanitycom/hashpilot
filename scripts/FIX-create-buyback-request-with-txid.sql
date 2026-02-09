-- ============================================
-- create_buyback_request関数にtransaction_idパラメータを追加
--
-- 問題: NFT返却TxIDが保存されない
-- 原因: RPC関数にtransaction_idパラメータがなく、
--       フロントエンドからの直接UPDATE（テーブル更新）がRLSでブロックされる
-- 解決: RPC関数でtransaction_idを受け取り、INSERTで一緒に保存
-- ============================================

DROP FUNCTION IF EXISTS create_buyback_request(TEXT, INTEGER, INTEGER, TEXT, TEXT);
DROP FUNCTION IF EXISTS create_buyback_request(TEXT, INTEGER, INTEGER, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION create_buyback_request(
    p_user_id TEXT,
    p_manual_nft_count INTEGER,
    p_auto_nft_count INTEGER,
    p_wallet_address TEXT,
    p_wallet_type TEXT,
    p_transaction_id TEXT DEFAULT NULL
)
RETURNS TABLE(
    request_id UUID,
    status TEXT,
    message TEXT,
    manual_buyback_amount DECIMAL(10,2),
    auto_buyback_amount DECIMAL(10,2),
    total_buyback_amount DECIMAL(10,2),
    success BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_request_id UUID;
    v_manual_buyback DECIMAL(10,2) := 0;
    v_auto_buyback DECIMAL(10,2) := 0;
    v_total_buyback DECIMAL(10,2) := 0;
    v_available_manual INTEGER := 0;
    v_available_auto INTEGER := 0;
    v_nft_record RECORD;
    v_nft_buyback DECIMAL(10,2);
BEGIN
    IF p_manual_nft_count < 0 OR p_auto_nft_count < 0 THEN
        RETURN QUERY SELECT NULL::UUID, 'ERROR'::TEXT, '無効なNFT数が指定されました'::TEXT, 0::DECIMAL(10,2), 0::DECIMAL(10,2), 0::DECIMAL(10,2), false::BOOLEAN;
        RETURN;
    END IF;

    IF p_manual_nft_count = 0 AND p_auto_nft_count = 0 THEN
        RETURN QUERY SELECT NULL::UUID, 'ERROR'::TEXT, '買い取りするNFTを選択してください'::TEXT, 0::DECIMAL(10,2), 0::DECIMAL(10,2), 0::DECIMAL(10,2), false::BOOLEAN;
        RETURN;
    END IF;

    IF p_transaction_id IS NULL OR p_transaction_id = '' THEN
        RETURN QUERY SELECT NULL::UUID, 'ERROR'::TEXT, 'NFT返却のトランザクションIDを入力してください'::TEXT, 0::DECIMAL(10,2), 0::DECIMAL(10,2), 0::DECIMAL(10,2), false::BOOLEAN;
        RETURN;
    END IF;

    SELECT COUNT(*) FILTER (WHERE nft_type = 'manual' AND buyback_date IS NULL), COUNT(*) FILTER (WHERE nft_type = 'auto' AND buyback_date IS NULL)
    INTO v_available_manual, v_available_auto FROM nft_master WHERE user_id = p_user_id;

    IF p_manual_nft_count > v_available_manual THEN
        RETURN QUERY SELECT NULL::UUID, 'ERROR'::TEXT, FORMAT('手動NFTの保有数が不足しています（保有: %s枚、申請: %s枚）', v_available_manual, p_manual_nft_count)::TEXT, 0::DECIMAL(10,2), 0::DECIMAL(10,2), 0::DECIMAL(10,2), false::BOOLEAN;
        RETURN;
    END IF;

    IF p_auto_nft_count > v_available_auto THEN
        RETURN QUERY SELECT NULL::UUID, 'ERROR'::TEXT, FORMAT('自動NFTの保有数が不足しています（保有: %s枚、申請: %s枚）', v_available_auto, p_auto_nft_count)::TEXT, 0::DECIMAL(10,2), 0::DECIMAL(10,2), 0::DECIMAL(10,2), false::BOOLEAN;
        RETURN;
    END IF;

    FOR v_nft_record IN SELECT id FROM nft_master WHERE user_id = p_user_id AND nft_type = 'manual' AND buyback_date IS NULL ORDER BY nft_sequence ASC LIMIT p_manual_nft_count
    LOOP
        v_nft_buyback := calculate_nft_buyback_amount(v_nft_record.id);
        v_manual_buyback := v_manual_buyback + v_nft_buyback;
    END LOOP;

    FOR v_nft_record IN SELECT id FROM nft_master WHERE user_id = p_user_id AND nft_type = 'auto' AND buyback_date IS NULL ORDER BY nft_sequence ASC LIMIT p_auto_nft_count
    LOOP
        v_nft_buyback := calculate_nft_buyback_amount(v_nft_record.id);
        v_auto_buyback := v_auto_buyback + v_nft_buyback;
    END LOOP;

    v_total_buyback := v_manual_buyback + v_auto_buyback;

    INSERT INTO buyback_requests (user_id, manual_nft_count, auto_nft_count, total_nft_count, manual_buyback_amount, auto_buyback_amount, total_buyback_amount, wallet_address, wallet_type, transaction_id, status)
    VALUES (p_user_id, p_manual_nft_count, p_auto_nft_count, p_manual_nft_count + p_auto_nft_count, v_manual_buyback, v_auto_buyback, v_total_buyback, p_wallet_address, p_wallet_type, p_transaction_id, 'pending')
    RETURNING id INTO v_request_id;

    RETURN QUERY SELECT v_request_id, 'SUCCESS'::TEXT, FORMAT('買い取り申請を受け付けました。合計金額: $%s', v_total_buyback)::TEXT, v_manual_buyback, v_auto_buyback, v_total_buyback, true::BOOLEAN;

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT NULL::UUID, 'ERROR'::TEXT, FORMAT('エラーが発生しました: %s', SQLERRM)::TEXT, 0::DECIMAL(10,2), 0::DECIMAL(10,2), 0::DECIMAL(10,2), false::BOOLEAN;
END;
$$;

GRANT EXECUTE ON FUNCTION create_buyback_request(TEXT, INTEGER, INTEGER, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION create_buyback_request(TEXT, INTEGER, INTEGER, TEXT, TEXT, TEXT) TO anon;
