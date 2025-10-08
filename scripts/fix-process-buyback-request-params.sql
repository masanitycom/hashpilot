-- process_buyback_request関数のパラメータを修正
-- p_admin_user_id UUID → p_admin_email TEXT に変更

DROP FUNCTION IF EXISTS process_buyback_request(UUID, TEXT, UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION process_buyback_request(
    p_request_id UUID,
    p_action TEXT,
    p_admin_email TEXT,  -- UUIDからTEXTに変更
    p_transaction_hash TEXT DEFAULT NULL,
    p_admin_notes TEXT DEFAULT NULL
)
RETURNS TABLE(
    status TEXT,
    message TEXT,
    success BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_request RECORD;
    v_nft_ids UUID[];
BEGIN
    -- 買い取り申請を取得
    SELECT * INTO v_request
    FROM buyback_requests
    WHERE id = p_request_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            '買い取り申請が見つかりません'::TEXT,
            false::BOOLEAN;
        RETURN;
    END IF;

    -- ステータスチェック
    IF v_request.status != 'pending' THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            'この申請は既に処理済みです'::TEXT,
            false::BOOLEAN;
        RETURN;
    END IF;

    -- アクションによる処理分岐
    IF p_action = 'complete' THEN
        -- 買い取り完了処理

        -- 対象NFTのIDを取得（古い順）
        SELECT ARRAY_AGG(id ORDER BY nft_sequence)
        INTO v_nft_ids
        FROM (
            SELECT id, nft_sequence
            FROM nft_master
            WHERE user_id = v_request.user_id
              AND buyback_date IS NULL
              AND (
                  (nft_type = 'manual' AND nft_sequence <= v_request.manual_nft_count)
                  OR
                  (nft_type = 'auto' AND nft_sequence <= v_request.auto_nft_count)
              )
        ) sub;

        -- NFTをbuyback済みにする
        UPDATE nft_master
        SET
            buyback_date = NOW()::DATE,
            updated_at = NOW()
        WHERE user_id = v_request.user_id
          AND buyback_date IS NULL
          AND (
              (nft_type = 'manual' AND nft_sequence IN (
                  SELECT nft_sequence FROM nft_master
                  WHERE user_id = v_request.user_id
                    AND nft_type = 'manual'
                    AND buyback_date IS NULL
                  ORDER BY nft_sequence ASC
                  LIMIT v_request.manual_nft_count
              ))
              OR
              (nft_type = 'auto' AND nft_sequence IN (
                  SELECT nft_sequence FROM nft_master
                  WHERE user_id = v_request.user_id
                    AND nft_type = 'auto'
                    AND buyback_date IS NULL
                  ORDER BY nft_sequence ASC
                  LIMIT v_request.auto_nft_count
              ))
          );

        -- affiliate_cycleのNFTカウントを減らす
        UPDATE affiliate_cycle
        SET
            manual_nft_count = manual_nft_count - v_request.manual_nft_count,
            auto_nft_count = auto_nft_count - v_request.auto_nft_count,
            total_nft_count = total_nft_count - v_request.total_nft_count,
            last_updated = NOW()
        WHERE user_id = v_request.user_id;

        -- 買い取り申請を完了にする
        UPDATE buyback_requests
        SET
            status = 'completed',
            processed_by = p_admin_email,
            processed_at = NOW(),
            transaction_hash = p_transaction_hash,
            admin_notes = p_admin_notes,
            updated_at = NOW()
        WHERE id = p_request_id;

        RETURN QUERY SELECT
            'SUCCESS'::TEXT,
            '買い取りが完了しました'::TEXT,
            true::BOOLEAN;

    ELSIF p_action = 'cancel' THEN
        -- 買い取り却下処理
        UPDATE buyback_requests
        SET
            status = 'cancelled',
            processed_by = p_admin_email,
            processed_at = NOW(),
            admin_notes = p_admin_notes,
            updated_at = NOW()
        WHERE id = p_request_id;

        RETURN QUERY SELECT
            'SUCCESS'::TEXT,
            '買い取り申請を却下しました'::TEXT,
            true::BOOLEAN;

    ELSE
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            '無効なアクションです'::TEXT,
            false::BOOLEAN;
    END IF;

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT
        'ERROR'::TEXT,
        FORMAT('エラーが発生しました: %s', SQLERRM)::TEXT,
        false::BOOLEAN;
END;
$$;

GRANT EXECUTE ON FUNCTION process_buyback_request(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION process_buyback_request(UUID, TEXT, TEXT, TEXT, TEXT) TO anon;

-- テスト
DO $$
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE '✅ process_buyback_request関数を修正';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '修正内容:';
    RAISE NOTICE '  - p_admin_user_id UUID → p_admin_email TEXT';
    RAISE NOTICE '  - 戻り値にstatusフィールド追加';
    RAISE NOTICE '  - NFTのbuyback処理を追加';
    RAISE NOTICE '  - affiliate_cycleのカウント減算を追加';
    RAISE NOTICE '=========================================';
END $$;
