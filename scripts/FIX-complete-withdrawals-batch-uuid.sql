-- ========================================
-- 出金完了処理関数の修正
-- 問題: monthly_withdrawals.id はUUID型だが、関数がINTEGERを期待していた
-- 解決: UUID[]を受け取るように修正
-- ========================================

-- 既存の関数を削除（引数型が異なるため）
DROP FUNCTION IF EXISTS complete_withdrawal(INTEGER);
DROP FUNCTION IF EXISTS complete_withdrawals_batch(INTEGER[]);

-- ========================================
-- 単一出金完了処理関数（UUID版）
-- ========================================

CREATE OR REPLACE FUNCTION complete_withdrawal(
    p_withdrawal_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id VARCHAR(6);
    v_amount NUMERIC;
    v_current_available NUMERIC;
BEGIN
    -- 出金レコードを取得
    SELECT user_id, total_amount
    INTO v_user_id, v_amount
    FROM monthly_withdrawals
    WHERE id = p_withdrawal_id
      AND status IN ('pending', 'on_hold');

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION '出金レコードが見つかりません、または既に完了済みです';
    END IF;

    -- 現在の available_usdt を取得
    SELECT available_usdt
    INTO v_current_available
    FROM affiliate_cycle
    WHERE user_id = v_user_id;

    IF v_current_available IS NULL THEN
        RAISE EXCEPTION 'ユーザーの affiliate_cycle レコードが見つかりません';
    END IF;

    -- available_usdt から出金額を減算（0未満にならないように）
    UPDATE affiliate_cycle
    SET
        available_usdt = GREATEST(0, available_usdt - v_amount),
        last_updated = NOW()
    WHERE user_id = v_user_id;

    -- 出金レコードを完了済みに更新
    UPDATE monthly_withdrawals
    SET
        status = 'completed',
        completed_at = NOW(),
        updated_at = NOW()
    WHERE id = p_withdrawal_id;

    RETURN TRUE;
END;
$$;

-- ========================================
-- 複数の出金を一括完了する関数（UUID版）
-- ========================================

CREATE OR REPLACE FUNCTION complete_withdrawals_batch(
    p_withdrawal_ids UUID[]
)
RETURNS TABLE(
    withdrawal_id UUID,
    user_id VARCHAR(6),
    amount NUMERIC,
    success BOOLEAN,
    error_message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_withdrawal_id UUID;
BEGIN
    FOREACH v_withdrawal_id IN ARRAY p_withdrawal_ids
    LOOP
        BEGIN
            -- 各出金を完了処理
            DECLARE
                v_user_id VARCHAR(6);
                v_amount NUMERIC;
            BEGIN
                SELECT mw.user_id, mw.total_amount
                INTO v_user_id, v_amount
                FROM monthly_withdrawals mw
                WHERE mw.id = v_withdrawal_id
                  AND mw.status IN ('pending', 'on_hold');

                IF v_user_id IS NULL THEN
                    RETURN QUERY SELECT
                        v_withdrawal_id,
                        NULL::VARCHAR(6),
                        0::NUMERIC,
                        FALSE,
                        '出金レコードが見つかりません、または既に完了済みです'::TEXT;
                    CONTINUE;
                END IF;

                -- available_usdt から出金額を減算
                UPDATE affiliate_cycle
                SET
                    available_usdt = GREATEST(0, available_usdt - v_amount),
                    last_updated = NOW()
                WHERE user_id = v_user_id;

                -- 出金レコードを完了済みに更新
                UPDATE monthly_withdrawals
                SET
                    status = 'completed',
                    completed_at = NOW(),
                    updated_at = NOW()
                WHERE id = v_withdrawal_id;

                RETURN QUERY SELECT
                    v_withdrawal_id,
                    v_user_id,
                    v_amount,
                    TRUE,
                    ''::TEXT;
            END;
        EXCEPTION WHEN OTHERS THEN
            RETURN QUERY SELECT
                v_withdrawal_id,
                NULL::VARCHAR(6),
                0::NUMERIC,
                FALSE,
                SQLERRM::TEXT;
        END;
    END LOOP;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION complete_withdrawal(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION complete_withdrawals_batch(UUID[]) TO authenticated;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ 出金完了処理関数を修正しました（UUID版）';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '変更内容:';
    RAISE NOTICE '  - 引数をINTEGERからUUIDに変更';
    RAISE NOTICE '  - monthly_withdrawals.id（UUID型）と互換性あり';
    RAISE NOTICE '===========================================';
END $$;
