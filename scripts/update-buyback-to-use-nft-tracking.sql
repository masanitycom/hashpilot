-- NFT買い取り計算ロジックを修正（NFTごとの利益を使用）
-- 作成日: 2025年10月7日
--
-- このスクリプトは買い取り申請処理を更新し、
-- NFTごとの利益データ（nft_master, nft_daily_profit）を使用して
-- 正確な買い取り金額を計算するようにします。

-- ============================================
-- 買い取り申請作成関数の更新
-- NFTごとの利益を使用した正確な計算
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
    total_buyback_amount DECIMAL(10,2)
)
LANGUAGE plpgsql
SECURITY DEFINER
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
            0::DECIMAL(10,2);
        RETURN;
    END IF;

    IF p_manual_nft_count = 0 AND p_auto_nft_count = 0 THEN
        RETURN QUERY SELECT
            NULL::UUID,
            'ERROR'::TEXT,
            '買い取りするNFTを選択してください'::TEXT,
            0::DECIMAL(10,2),
            0::DECIMAL(10,2),
            0::DECIMAL(10,2);
        RETURN;
    END IF;

    -- 保有中のNFT数を確認（nft_masterテーブルから取得）
    SELECT
        COUNT(*) FILTER (WHERE nft_type = 'manual'),
        COUNT(*) FILTER (WHERE nft_type = 'auto')
    INTO v_available_manual, v_available_auto
    FROM nft_master
    WHERE user_id = p_user_id
      AND buyback_date IS NULL;  -- 保有中のみ

    -- NFT保有数の検証
    IF p_manual_nft_count > v_available_manual THEN
        RETURN QUERY SELECT
            NULL::UUID,
            'ERROR'::TEXT,
            FORMAT('手動NFTの保有数が不足しています（保有: %s枚、申請: %s枚）',
                v_available_manual, p_manual_nft_count)::TEXT,
            0::DECIMAL(10,2),
            0::DECIMAL(10,2),
            0::DECIMAL(10,2);
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
            0::DECIMAL(10,2);
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
        ORDER BY nft_sequence ASC  -- 古い順
        LIMIT p_manual_nft_count
    LOOP
        -- NFTごとの買い取り金額を計算
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
        ORDER BY nft_sequence ASC  -- 古い順
        LIMIT p_auto_nft_count
    LOOP
        -- NFTごとの買い取り金額を計算
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
        v_total_buyback;

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT
        NULL::UUID,
        'ERROR'::TEXT,
        FORMAT('エラーが発生しました: %s', SQLERRM)::TEXT,
        0::DECIMAL(10,2),
        0::DECIMAL(10,2),
        0::DECIMAL(10,2);
END;
$$;

-- 実行権限付与
GRANT EXECUTE ON FUNCTION create_buyback_request(TEXT, INTEGER, INTEGER, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION create_buyback_request(TEXT, INTEGER, INTEGER, TEXT, TEXT) TO authenticated;

-- ============================================
-- 買い取り申請処理関数（承認/キャンセル）
-- NFT のbuyback_dateを更新する
-- ============================================

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
            '無効なアクションです'::TEXT;
    END IF;

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT
        'ERROR'::TEXT,
        FORMAT('エラーが発生しました: %s', SQLERRM)::TEXT;
END;
$$;

-- 実行権限付与
GRANT EXECUTE ON FUNCTION process_buyback_request(UUID, TEXT, TEXT, TEXT, TEXT) TO anon;
GRANT EXECUTE ON FUNCTION process_buyback_request(UUID, TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '✅ NFT買い取り申請処理を更新しました';
    RAISE NOTICE '📋 更新内容:';
    RAISE NOTICE '   - create_buyback_request: NFTごとの利益を使用した正確な買い取り金額計算';
    RAISE NOTICE '   - process_buyback_request: 承認時にNFTのbuyback_dateを設定';
    RAISE NOTICE '   - 古いNFTから順に買い取り対象とする';
END $$;
