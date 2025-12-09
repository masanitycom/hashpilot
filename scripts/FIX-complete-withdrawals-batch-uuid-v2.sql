-- ========================================
-- 出金完了処理関数の修正 v2
-- 問題: "user_id" is ambiguous エラー
-- 原因: RETURNS TABLE の user_id と内部変数の競合
-- 解決: 戻り値のカラム名を変更
-- ========================================

DROP FUNCTION IF EXISTS complete_withdrawals_batch(UUID[]);

CREATE OR REPLACE FUNCTION complete_withdrawals_batch(
    p_withdrawal_ids UUID[]
)
RETURNS TABLE(
    out_withdrawal_id UUID,
    out_user_id VARCHAR(6),
    out_amount NUMERIC,
    out_success BOOLEAN,
    out_error_message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_withdrawal_id UUID;
    v_user_id VARCHAR(6);
    v_amount NUMERIC;
BEGIN
    FOREACH v_withdrawal_id IN ARRAY p_withdrawal_ids
    LOOP
        BEGIN
            -- 出金レコードを取得
            SELECT mw.user_id, mw.total_amount
            INTO v_user_id, v_amount
            FROM monthly_withdrawals mw
            WHERE mw.id = v_withdrawal_id
              AND mw.status IN ('pending', 'on_hold');

            IF v_user_id IS NULL THEN
                out_withdrawal_id := v_withdrawal_id;
                out_user_id := NULL;
                out_amount := 0;
                out_success := FALSE;
                out_error_message := '出金レコードが見つかりません、または既に完了済みです';
                RETURN NEXT;
                CONTINUE;
            END IF;

            -- available_usdt から出金額を減算
            UPDATE affiliate_cycle ac
            SET
                available_usdt = GREATEST(0, ac.available_usdt - v_amount),
                last_updated = NOW()
            WHERE ac.user_id = v_user_id;

            -- 出金レコードを完了済みに更新
            UPDATE monthly_withdrawals mw
            SET
                status = 'completed',
                completed_at = NOW(),
                updated_at = NOW()
            WHERE mw.id = v_withdrawal_id;

            out_withdrawal_id := v_withdrawal_id;
            out_user_id := v_user_id;
            out_amount := v_amount;
            out_success := TRUE;
            out_error_message := '';
            RETURN NEXT;

        EXCEPTION WHEN OTHERS THEN
            out_withdrawal_id := v_withdrawal_id;
            out_user_id := NULL;
            out_amount := 0;
            out_success := FALSE;
            out_error_message := SQLERRM;
            RETURN NEXT;
        END;
    END LOOP;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION complete_withdrawals_batch(UUID[]) TO authenticated;

-- 確認
SELECT '✅ complete_withdrawals_batch 関数を修正しました（user_id曖昧性エラー解消）' as status;
