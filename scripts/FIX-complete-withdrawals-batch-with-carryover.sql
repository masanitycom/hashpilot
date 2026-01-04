-- ========================================
-- complete_withdrawals_batch関数の改修
-- 繰越元の月も自動的に完了にする
-- ========================================

-- 既存関数を削除
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
    v_prev_withdrawal RECORD;
    v_prev_count INTEGER := 0;
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

            -- ========================================
            -- 後の月が未完了の場合はエラー（新機能）
            -- 例：12月が未完了なのに11月を完了しようとした場合
            -- ========================================
            DECLARE
                v_later_month DATE;
                v_later_month_str TEXT;
            BEGIN
                SELECT withdrawal_month INTO v_later_month
                FROM monthly_withdrawals
                WHERE user_id = v_user_id
                  AND withdrawal_month > v_withdrawal_month
                  AND status IN ('pending', 'on_hold')
                ORDER BY withdrawal_month ASC
                LIMIT 1;

                IF v_later_month IS NOT NULL THEN
                    v_later_month_str := TO_CHAR(v_later_month, 'YYYY年MM月');
                    out_withdrawal_id := v_withdrawal_id;
                    out_user_id := v_user_id;
                    out_amount := 0;
                    out_success := FALSE;
                    out_error_message := v_later_month_str || 'に繰越が含まれています。' || v_later_month_str || '分を先に完了してください';
                    RETURN NEXT;
                    CONTINUE;
                END IF;
            END;

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

            -- ========================================
            -- 繰越元の月も自動的に完了にする（新機能）
            -- ========================================
            -- このユーザーの、この月より前の、未完了の出金レコードを全て完了にする
            v_prev_count := 0;
            FOR v_prev_withdrawal IN
                SELECT id, withdrawal_month, total_amount
                FROM monthly_withdrawals
                WHERE user_id = v_user_id
                  AND withdrawal_month < v_withdrawal_month
                  AND status IN ('pending', 'on_hold')
                ORDER BY withdrawal_month ASC
            LOOP
                -- 繰越元の月を完了にする
                UPDATE monthly_withdrawals
                SET
                    status = 'completed',
                    completed_at = NOW(),
                    updated_at = NOW(),
                    notes = COALESCE(notes, '') ||
                            CASE WHEN notes IS NOT NULL AND notes != '' THEN ' | ' ELSE '' END ||
                            TO_CHAR(v_withdrawal_month, 'YYYY年MM月') || '分と合算して送金済み'
                WHERE id = v_prev_withdrawal.id;

                v_prev_count := v_prev_count + 1;
            END LOOP;

            -- 結果を返す
            out_withdrawal_id := v_withdrawal_id;
            out_user_id := v_user_id;
            out_amount := v_total_amount;
            out_success := TRUE;
            -- 繰越元がある場合はメッセージに追加
            IF v_prev_count > 0 THEN
                out_error_message := v_prev_count || '件の繰越元も完了にしました';
            ELSE
                out_error_message := '';
            END IF;
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

-- ========================================
-- 確認用クエリ
-- ========================================
SELECT '✅ complete_withdrawals_batch 関数を改修しました' as status;
SELECT '改修内容:' as info;
SELECT '  1. 後の月が未完了の場合はエラー（11月を完了しようとして12月が未完了ならエラー）' as detail1;
SELECT '  2. 繰越元の月（pending/on_hold）を自動的に完了にする' as detail2;
SELECT '  3. 繰越元にはnotesに「YYYY年MM月分と合算して送金済み」と記録' as detail3;
SELECT '  4. 結果のerror_messageに「X件の繰越元も完了にしました」と表示' as detail4;
