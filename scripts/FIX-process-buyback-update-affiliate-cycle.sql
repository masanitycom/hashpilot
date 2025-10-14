-- ========================================
-- 修正: process_buyback_request関数にaffiliate_cycle更新を追加
-- ========================================

-- 既存の関数を削除
DROP FUNCTION IF EXISTS process_buyback_request(uuid, text, text, text, text);

-- 新しい関数を作成
CREATE OR REPLACE FUNCTION process_buyback_request(
    p_request_id UUID,
    p_action TEXT,  -- 'complete' or 'cancel'
    p_transaction_hash TEXT DEFAULT NULL,
    p_admin_notes TEXT DEFAULT NULL,
    p_admin_email TEXT DEFAULT NULL
)
RETURNS TABLE(
    status TEXT,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_request_record RECORD;
    v_nft_record RECORD;
    v_count_manual INTEGER := 0;
    v_count_auto INTEGER := 0;
BEGIN
    -- 買い取り申請を取得
    SELECT * INTO v_request_record
    FROM buyback_requests
    WHERE id = p_request_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            '買い取り申請が見つかりません'::TEXT;
        RETURN;
    END IF;

    IF v_request_record.status != 'pending' THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            FORMAT('この申請は既に処理されています（ステータス: %s）', v_request_record.status)::TEXT;
        RETURN;
    END IF;

    IF p_action = 'complete' THEN
        -- 承認処理: NFTのbuyback_dateを設定（古い順に選択）

        -- 手動NFT
        v_count_manual := 0;
        FOR v_nft_record IN
            SELECT id
            FROM nft_master
            WHERE user_id = v_request_record.user_id
              AND nft_type = 'manual'
              AND buyback_date IS NULL
            ORDER BY nft_sequence ASC
            LIMIT v_request_record.manual_nft_count
        LOOP
            UPDATE nft_master
            SET buyback_date = CURRENT_DATE,
                updated_at = NOW()
            WHERE id = v_nft_record.id;

            v_count_manual := v_count_manual + 1;
        END LOOP;

        -- 自動NFT
        v_count_auto := 0;
        FOR v_nft_record IN
            SELECT id
            FROM nft_master
            WHERE user_id = v_request_record.user_id
              AND nft_type = 'auto'
              AND buyback_date IS NULL
            ORDER BY nft_sequence ASC
            LIMIT v_request_record.auto_nft_count
        LOOP
            UPDATE nft_master
            SET buyback_date = CURRENT_DATE,
                updated_at = NOW()
            WHERE id = v_nft_record.id;

            v_count_auto := v_count_auto + 1;
        END LOOP;

        -- ⭐ 修正: affiliate_cycleを更新（NFT枚数を減らす）
        UPDATE affiliate_cycle
        SET
            manual_nft_count = manual_nft_count - v_count_manual,
            auto_nft_count = auto_nft_count - v_count_auto,
            total_nft_count = total_nft_count - (v_count_manual + v_count_auto),
            last_updated = NOW()
        WHERE user_id = v_request_record.user_id;

        -- 買い取り申請を完了に更新
        UPDATE buyback_requests
        SET
            status = 'completed',
            processed_at = NOW(),
            processed_by = p_admin_email,
            transaction_hash = p_transaction_hash
        WHERE id = p_request_id;

        RETURN QUERY SELECT
            'SUCCESS'::TEXT,
            FORMAT('買い取り申請を承認しました（手動: %s枚, 自動: %s枚）',
                v_count_manual, v_count_auto)::TEXT;

    ELSIF p_action = 'cancel' THEN
        -- キャンセル処理
        UPDATE buyback_requests
        SET
            status = 'cancelled',
            processed_at = NOW(),
            processed_by = p_admin_email
        WHERE id = p_request_id;

        RETURN QUERY SELECT
            'SUCCESS'::TEXT,
            '買い取り申請をキャンセルしました'::TEXT;

    ELSE
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            FORMAT('無効なアクション: %s', p_action)::TEXT;
    END IF;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION process_buyback_request(UUID, TEXT, TEXT, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION process_buyback_request(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE '✅ process_buyback_request関数を修正しました';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '追加内容:';
    RAISE NOTICE '  - NFT買い取り承認時にaffiliate_cycleを更新';
    RAISE NOTICE '  - manual_nft_count, auto_nft_count, total_nft_count を減算';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️ 重要: 既存の買い取り済みデータは手動で修正が必要';
    RAISE NOTICE '=========================================';
END $$;
