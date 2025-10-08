-- NFT買い取り申請の権限エラーを修正
-- エラー: permission denied for table users
-- 原因: get_buyback_requests関数が存在しないか、SECURITY DEFINERが設定されていない

-- ============================================
-- STEP 1: 既存関数を削除
-- ============================================

DROP FUNCTION IF EXISTS get_buyback_requests(TEXT);
DROP FUNCTION IF EXISTS create_buyback_request(TEXT, INTEGER, INTEGER, TEXT, TEXT);

-- ============================================
-- STEP 2: get_buyback_requests関数を作成
-- ============================================

CREATE OR REPLACE FUNCTION get_buyback_requests(p_user_id TEXT)
RETURNS TABLE(
    id UUID,
    user_id TEXT,
    request_date DATE,
    manual_nft_count INTEGER,
    auto_nft_count INTEGER,
    total_nft_count INTEGER,
    manual_buyback_amount DECIMAL(10,2),
    auto_buyback_amount DECIMAL(10,2),
    total_buyback_amount DECIMAL(10,2),
    wallet_address TEXT,
    wallet_type TEXT,
    status TEXT,
    processed_by TEXT,
    processed_at TIMESTAMP WITH TIME ZONE,
    transaction_hash TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    SELECT
        br.id,
        br.user_id,
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
        br.transaction_hash
    FROM buyback_requests br
    WHERE br.user_id = p_user_id
    ORDER BY br.request_date DESC, br.created_at DESC;
END;
$$;

-- ============================================
-- STEP 3: create_buyback_request関数を作成
-- ============================================
CREATE OR REPLACE FUNCTION create_buyback_request(
    p_user_id TEXT,
    p_manual_nft_count INTEGER,
    p_auto_nft_count INTEGER,
    p_wallet_address TEXT,
    p_wallet_type TEXT
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
    v_count_manual INTEGER := 0;
    v_count_auto INTEGER := 0;
BEGIN
    -- 入力値検証
    IF p_manual_nft_count < 0 OR p_auto_nft_count < 0 THEN
        RETURN QUERY SELECT
            NULL::UUID,
            'ERROR'::TEXT,
            '無効な NFT 数が指定されました'::TEXT,
            0::DECIMAL(10,2),
            0::DECIMAL(10,2),
            0::DECIMAL(10,2),
            false::BOOLEAN;
        RETURN;
    END IF;

    IF p_manual_nft_count = 0 AND p_auto_nft_count = 0 THEN
        RETURN QUERY SELECT
            NULL::UUID,
            'ERROR'::TEXT,
            '買い取りするNFTを選択してください'::TEXT,
            0::DECIMAL(10,2),
            0::DECIMAL(10,2),
            0::DECIMAL(10,2),
            false::BOOLEAN;
        RETURN;
    END IF;

    -- 保有中のNFT数を確認（nft_masterテーブルから取得）
    SELECT
        COUNT(*) FILTER (WHERE nft_type = 'manual'),
        COUNT(*) FILTER (WHERE nft_type = 'auto')
    INTO v_available_manual, v_available_auto
    FROM nft_master
    WHERE user_id = p_user_id
      AND buyback_date IS NULL;

    -- NFT保有数の検証
    IF p_manual_nft_count > v_available_manual THEN
        RETURN QUERY SELECT
            NULL::UUID,
            'ERROR'::TEXT,
            FORMAT('手動NFTの保有数が不足しています（保有: %s枚、申請: %s枚）',
                v_available_manual, p_manual_nft_count)::TEXT,
            0::DECIMAL(10,2),
            0::DECIMAL(10,2),
            0::DECIMAL(10,2),
            false::BOOLEAN;
        RETURN;
    END IF;

    IF p_auto_nft_count > v_available_auto THEN
        RETURN QUERY SELECT
            NULL::UUID,
            'ERROR'::TEXT,
            FORMAT('自動NFTの保有数が不足しています（保有: %s枚、申請: %s枚）',
                v_available_auto, p_auto_nft_count)::TEXT,
            0::DECIMAL(10,2),
            0::DECIMAL(10,2),
            0::DECIMAL(10,2),
            false::BOOLEAN;
        RETURN;
    END IF;

    -- ★★★ NFTごとの買い取り金額を計算 ★★★
    -- 手動NFTの買い取り金額計算（古い順に選択）
    v_count_manual := 0;
    FOR v_nft_record IN
        SELECT id, nft_sequence
        FROM nft_master
        WHERE user_id = p_user_id
          AND nft_type = 'manual'
          AND buyback_date IS NULL
        ORDER BY nft_sequence ASC
        LIMIT p_manual_nft_count
    LOOP
        v_nft_buyback := calculate_nft_buyback_amount(v_nft_record.id);
        v_manual_buyback := v_manual_buyback + v_nft_buyback;
        v_count_manual := v_count_manual + 1;
    END LOOP;

    -- 自動NFTの買い取り金額計算（古い順に選択）
    v_count_auto := 0;
    FOR v_nft_record IN
        SELECT id, nft_sequence
        FROM nft_master
        WHERE user_id = p_user_id
          AND nft_type = 'auto'
          AND buyback_date IS NULL
        ORDER BY nft_sequence ASC
        LIMIT p_auto_nft_count
    LOOP
        v_nft_buyback := calculate_nft_buyback_amount(v_nft_record.id);
        v_auto_buyback := v_auto_buyback + v_nft_buyback;
        v_count_auto := v_count_auto + 1;
    END LOOP;

    v_total_buyback := v_manual_buyback + v_auto_buyback;

    -- 買い取り申請レコードを作成
    INSERT INTO buyback_requests (
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
    )
    VALUES (
        p_user_id,
        CURRENT_DATE,
        p_manual_nft_count,
        p_auto_nft_count,
        p_manual_nft_count + p_auto_nft_count,
        v_manual_buyback,
        v_auto_buyback,
        v_total_buyback,
        p_wallet_address,
        p_wallet_type,
        'pending'
    )
    RETURNING id INTO v_request_id;

    -- 成功レスポンス
    RETURN QUERY SELECT
        v_request_id,
        'SUCCESS'::TEXT,
        FORMAT('買い取り申請を受け付けました。合計金額: $%s', v_total_buyback)::TEXT,
        v_manual_buyback,
        v_auto_buyback,
        v_total_buyback,
        true::BOOLEAN;

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT
        NULL::UUID,
        'ERROR'::TEXT,
        FORMAT('エラーが発生しました: %s', SQLERRM)::TEXT,
        0::DECIMAL(10,2),
        0::DECIMAL(10,2),
        0::DECIMAL(10,2),
        false::BOOLEAN;
END;
$$;

-- ============================================
-- STEP 4: 権限付与
-- ============================================

GRANT EXECUTE ON FUNCTION get_buyback_requests(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION get_buyback_requests(TEXT) TO authenticated;

GRANT EXECUTE ON FUNCTION create_buyback_request(TEXT, INTEGER, INTEGER, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION create_buyback_request(TEXT, INTEGER, INTEGER, TEXT, TEXT) TO authenticated;

-- ============================================
-- 完了メッセージ
-- ============================================

DO $$
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE '✅ NFT買い取り申請の権限エラーを修正しました';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '修正内容:';
    RAISE NOTICE '  1. 既存関数を削除';
    RAISE NOTICE '  2. get_buyback_requests関数を作成（SECURITY DEFINER）';
    RAISE NOTICE '  3. create_buyback_request関数を作成（SET search_path追加）';
    RAISE NOTICE '  4. 両関数に権限を付与（anon, authenticated）';
    RAISE NOTICE '';
    RAISE NOTICE 'これでユーザー側から買い取り申請できるようになります';
    RAISE NOTICE '=========================================';
END $$;
