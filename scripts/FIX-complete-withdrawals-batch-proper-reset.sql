-- ========================================
-- complete_withdrawals_batch関数の修正
-- 出金完了時にavailable_usdtを正しくリセット
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
    v_total_amount NUMERIC;
    v_personal_amount NUMERIC;
    v_referral_amount NUMERIC;
    v_withdrawal_month DATE;
    v_next_month_start DATE;
    v_future_profit NUMERIC;
BEGIN
    FOREACH v_withdrawal_id IN ARRAY p_withdrawal_ids
    LOOP
        BEGIN
            -- 出金レコードを取得
            SELECT
                mw.user_id,
                mw.total_amount,
                COALESCE(mw.personal_amount, mw.total_amount) as personal_amt,
                COALESCE(mw.referral_amount, 0) as referral_amt,
                mw.withdrawal_month
            INTO v_user_id, v_total_amount, v_personal_amount, v_referral_amount, v_withdrawal_month
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

            -- 翌月1日を計算
            v_next_month_start := (DATE_TRUNC('month', v_withdrawal_month) + INTERVAL '1 month')::DATE;

            -- 翌月以降の日利を計算（出金完了後に残るべき金額）
            SELECT COALESCE(SUM(daily_profit), 0)
            INTO v_future_profit
            FROM nft_daily_profit
            WHERE user_id = v_user_id
              AND date >= v_next_month_start;

            -- affiliate_cycleを更新
            UPDATE affiliate_cycle ac
            SET
                -- available_usdtは翌月以降の日利のみにリセット
                available_usdt = v_future_profit,
                -- 出金した紹介報酬を記録
                withdrawn_referral_usdt = COALESCE(ac.withdrawn_referral_usdt, 0) + v_referral_amount,
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
            out_amount := v_total_amount;
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

-- 確認メッセージ
SELECT '✅ complete_withdrawals_batch 関数を修正しました' as status;
SELECT '修正内容:' as info;
SELECT '  1. available_usdt を翌月以降の日利のみにリセット' as detail1;
SELECT '  2. withdrawn_referral_usdt に出金した紹介報酬を加算' as detail2;
