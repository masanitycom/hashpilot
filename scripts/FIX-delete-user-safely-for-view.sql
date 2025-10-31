-- ========================================
-- delete_user_safely 関数を修正
-- ========================================
-- 問題: user_daily_profitがVIEWになったため削除できない
-- 解決: user_daily_profitをスキップして、nft_daily_profitのみ削除

DROP FUNCTION IF EXISTS delete_user_safely(TEXT, TEXT);

CREATE OR REPLACE FUNCTION delete_user_safely(
    p_user_id TEXT,
    p_admin_email TEXT
)
RETURNS TABLE(
    status TEXT,
    message TEXT,
    details JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted_tables JSONB := '[]'::JSONB;
    v_row_count INTEGER;
    v_user_email TEXT;
BEGIN
    -- ユーザーのメールアドレスを取得
    SELECT email INTO v_user_email
    FROM users
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            FORMAT('ユーザーID %s が見つかりません', p_user_id)::TEXT,
            '{}'::JSONB;
        RETURN;
    END IF;

    -- 削除処理開始
    RAISE NOTICE '削除開始: ユーザーID=%, メール=%', p_user_id, v_user_email;

    -- 1. nft_daily_profit から削除（user_daily_profitはVIEWなのでスキップ）
    DELETE FROM nft_daily_profit WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count > 0 THEN
        v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'nft_daily_profit', 'rows', v_row_count);
    END IF;

    -- 2. nft_holdings から削除
    DELETE FROM nft_holdings WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count > 0 THEN
        v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'nft_holdings', 'rows', v_row_count);
    END IF;

    -- 3. nft_master から削除
    DELETE FROM nft_master WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count > 0 THEN
        v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'nft_master', 'rows', v_row_count);
    END IF;

    -- 4. purchases から削除
    DELETE FROM purchases WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count > 0 THEN
        v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'purchases', 'rows', v_row_count);
    END IF;

    -- 5. buyback_requests から削除
    DELETE FROM buyback_requests WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count > 0 THEN
        v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'buyback_requests', 'rows', v_row_count);
    END IF;

    -- 6. monthly_withdrawals から削除
    DELETE FROM monthly_withdrawals WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count > 0 THEN
        v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'monthly_withdrawals', 'rows', v_row_count);
    END IF;

    -- 7. affiliate_cycle から削除
    DELETE FROM affiliate_cycle WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count > 0 THEN
        v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'affiliate_cycle', 'rows', v_row_count);
    END IF;

    -- 8. email_recipients から削除
    DELETE FROM email_recipients WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count > 0 THEN
        v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'email_recipients', 'rows', v_row_count);
    END IF;

    -- 9. monthly_reward_tasks から削除
    DELETE FROM monthly_reward_tasks WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count > 0 THEN
        v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'monthly_reward_tasks', 'rows', v_row_count);
    END IF;

    -- 10. このユーザーを紹介者としているユーザーの参照をNULLに
    UPDATE users SET referrer_user_id = NULL WHERE referrer_user_id = p_user_id;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count > 0 THEN
        v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'users(referrer更新)', 'rows', v_row_count);
    END IF;

    -- 11. 最後に users テーブルから削除
    DELETE FROM users WHERE user_id = p_user_id;
    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    IF v_row_count > 0 THEN
        v_deleted_tables := v_deleted_tables || jsonb_build_object('table', 'users', 'rows', v_row_count);
    END IF;

    -- 成功レスポンス
    RETURN QUERY SELECT
        'SUCCESS'::TEXT,
        FORMAT('ユーザー %s (ID: %s) を削除しました', v_user_email, p_user_id)::TEXT,
        jsonb_build_object(
            'deleted_from_tables', v_deleted_tables,
            'admin_email', p_admin_email,
            'deleted_user_email', v_user_email
        );

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT
        'ERROR'::TEXT,
        FORMAT('削除中にエラーが発生しました: %s', SQLERRM)::TEXT,
        jsonb_build_object('error_detail', SQLERRM);
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION delete_user_safely(TEXT, TEXT) TO authenticated;

-- 完了メッセージ
SELECT '✅ delete_user_safely 関数を修正しました（user_daily_profit VIEW対応）' as status;
