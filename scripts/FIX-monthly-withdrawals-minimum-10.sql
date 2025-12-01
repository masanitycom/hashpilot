-- ========================================
-- 月末自動出金の最低金額を$100 → $10に修正
-- ========================================

CREATE OR REPLACE FUNCTION process_monthly_withdrawals(
    p_target_month DATE DEFAULT NULL
)
RETURNS TABLE(
    processed_count INTEGER,
    total_amount NUMERIC,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_processed_count INTEGER := 0;
    v_total_amount NUMERIC := 0;
    v_target_month DATE;
    v_today DATE;
    v_last_day DATE;
    v_year INTEGER;
    v_month INTEGER;
    v_user_record RECORD;
BEGIN
    -- 日本時間での現在日付を取得
    v_today := (NOW() AT TIME ZONE 'Asia/Tokyo')::DATE;

    -- ターゲット月の設定（指定がなければ今月）
    IF p_target_month IS NULL THEN
        v_target_month := DATE_TRUNC('month', v_today)::DATE;
    ELSE
        v_target_month := DATE_TRUNC('month', p_target_month)::DATE;
    END IF;

    -- 月末日を計算
    v_last_day := (DATE_TRUNC('month', v_target_month) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

    -- 今日が月末でない場合は警告（手動実行の場合は継続）
    IF v_today != v_last_day AND p_target_month IS NULL THEN
        RAISE NOTICE '⚠️ 本日（%）は月末（%）ではありません。手動実行として処理を継続します。', v_today, v_last_day;
    END IF;

    v_year := EXTRACT(YEAR FROM v_target_month);
    v_month := EXTRACT(MONTH FROM v_target_month);

    -- ✅ 修正：最低出金額を$10に変更
    FOR v_user_record IN
        SELECT
            ac.user_id,
            u.email,
            ac.available_usdt,
            COALESCE(u.coinw_uid, '') as coinw_uid,
            COALESCE(u.nft_receive_address, '') as nft_receive_address,
            u.is_pegasus_exchange,
            u.pegasus_withdrawal_unlock_date
        FROM affiliate_cycle ac
        INNER JOIN users u ON ac.user_id = u.user_id
        WHERE ac.available_usdt >= 10  -- ✅ $100 → $10に修正
          AND NOT (
              COALESCE(u.is_pegasus_exchange, FALSE) = TRUE
              AND (
                  u.pegasus_withdrawal_unlock_date IS NULL
                  OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
              )
          )
          AND NOT EXISTS (
              SELECT 1
              FROM monthly_withdrawals mw
              WHERE mw.user_id = ac.user_id
                AND mw.withdrawal_month = v_target_month
          )
    LOOP
        DECLARE
            v_withdrawal_method TEXT;
            v_withdrawal_address TEXT;
            v_initial_status TEXT;
        BEGIN
            IF v_user_record.coinw_uid != '' THEN
                v_withdrawal_method := 'coinw';
                v_withdrawal_address := v_user_record.coinw_uid;
                v_initial_status := 'on_hold';
            ELSIF v_user_record.nft_receive_address != '' THEN
                v_withdrawal_method := 'bep20';
                v_withdrawal_address := v_user_record.nft_receive_address;
                v_initial_status := 'on_hold';
            ELSE
                v_withdrawal_method := NULL;
                v_withdrawal_address := NULL;
                v_initial_status := 'on_hold';
            END IF;

            INSERT INTO monthly_withdrawals (
                user_id,
                email,
                withdrawal_month,
                total_amount,
                withdrawal_method,
                withdrawal_address,
                status,
                task_completed,
                created_at,
                updated_at
            )
            VALUES (
                v_user_record.user_id,
                v_user_record.email,
                v_target_month,
                v_user_record.available_usdt,
                v_withdrawal_method,
                v_withdrawal_address,
                v_initial_status,
                false,
                NOW(),
                NOW()
            );

            INSERT INTO monthly_reward_tasks (
                user_id,
                year,
                month,
                is_completed,
                questions_answered,
                created_at,
                updated_at
            )
            VALUES (
                v_user_record.user_id,
                v_year,
                v_month,
                false,
                0,
                NOW(),
                NOW()
            )
            ON CONFLICT (user_id, year, month) DO NOTHING;

            v_processed_count := v_processed_count + 1;
            v_total_amount := v_total_amount + v_user_record.available_usdt;
        END;
    END LOOP;

    BEGIN
        INSERT INTO system_logs (
            log_type,
            message,
            details,
            created_at
        )
        VALUES (
            'monthly_withdrawal',
            FORMAT('月末出金処理完了: %s年%s月 - 出金申請%s件作成', v_year, v_month, v_processed_count),
            jsonb_build_object(
                'year', v_year,
                'month', v_month,
                'withdrawal_count', v_processed_count,
                'withdrawal_total', v_total_amount,
                'process_date', v_today,
                'target_month', v_target_month
            ),
            NOW()
        );
    EXCEPTION WHEN undefined_table THEN
        NULL;
    END;

    RETURN QUERY
    SELECT
        v_processed_count,
        v_total_amount,
        CASE
            WHEN v_processed_count = 0 THEN
                FORMAT('月末出金処理が完了しました。%s年%s月分 - 新規出金申請: 0件（既に処理済みまたは対象ユーザーなし）', v_year, v_month)
            ELSE
                FORMAT('月末出金処理が完了しました。%s年%s月分 - 出金申請: %s件（総額: $%s）', v_year, v_month, v_processed_count, v_total_amount::TEXT)
        END;
END;
$$;

SELECT 'process_monthly_withdrawals関数を修正しました（最低出金額: $100 → $10）' as status;
