-- ========================================
-- 月末出金処理関数（日本時間基準）
-- ========================================

-- 既存の関数を削除（戻り値の型が異なる場合に備えて）
DROP FUNCTION IF EXISTS process_monthly_withdrawals(DATE);

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

    -- 出金処理（available_usdt >= 10のユーザー）
    -- ⭐ ペガサス交換ユーザーで出金制限期間内のユーザーを除外
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
        WHERE ac.available_usdt >= 10  -- 最低出金額10 USDT
          -- ⭐ ペガサス交換ユーザーで出金制限期間内のユーザーを除外
          AND NOT (
              COALESCE(u.is_pegasus_exchange, FALSE) = TRUE
              AND (
                  u.pegasus_withdrawal_unlock_date IS NULL
                  OR CURRENT_DATE < u.pegasus_withdrawal_unlock_date
              )
          )
          -- 同月の出金申請が既に存在しないかチェック
          AND NOT EXISTS (
              SELECT 1
              FROM monthly_withdrawals mw
              WHERE mw.user_id = ac.user_id
                AND mw.withdrawal_month = v_target_month
          )
    LOOP
        -- 出金方法を決定
        DECLARE
            v_withdrawal_method TEXT;
            v_withdrawal_address TEXT;
            v_initial_status TEXT;
        BEGIN
            IF v_user_record.coinw_uid != '' THEN
                v_withdrawal_method := 'coinw';
                v_withdrawal_address := v_user_record.coinw_uid;
                v_initial_status := 'on_hold';  -- タスク未完了のため保留
            ELSIF v_user_record.nft_receive_address != '' THEN
                v_withdrawal_method := 'bep20';
                v_withdrawal_address := v_user_record.nft_receive_address;
                v_initial_status := 'on_hold';  -- タスク未完了のため保留
            ELSE
                v_withdrawal_method := NULL;
                v_withdrawal_address := NULL;
                v_initial_status := 'on_hold';  -- 設定なし＋タスク未完了
            END IF;

            -- 出金申請レコードを作成
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
                false,  -- タスク未完了
                NOW(),
                NOW()
            );

            -- 月末タスクレコードを作成
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

    -- ログ記録
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

-- ========================================
-- タスク完了処理関数の更新
-- タスク完了時に出金申請のステータスを更新
-- ========================================

-- 既存の関数を削除（戻り値の型が異なる場合に備えて）
DROP FUNCTION IF EXISTS complete_reward_task(VARCHAR(6), JSONB);

CREATE OR REPLACE FUNCTION complete_reward_task(
    p_user_id VARCHAR(6),
    p_answers JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_year INTEGER;
    v_current_month INTEGER;
    v_task_exists BOOLEAN;
    v_withdrawal_month DATE;
BEGIN
    -- 現在の年月を取得（日本時間）
    v_current_year := EXTRACT(YEAR FROM (NOW() AT TIME ZONE 'Asia/Tokyo'));
    v_current_month := EXTRACT(MONTH FROM (NOW() AT TIME ZONE 'Asia/Tokyo'));
    v_withdrawal_month := DATE(v_current_year || '-' || LPAD(v_current_month::TEXT, 2, '0') || '-01');

    -- タスクレコードの存在確認
    SELECT EXISTS(
        SELECT 1 FROM monthly_reward_tasks
        WHERE user_id = p_user_id
        AND year = v_current_year
        AND month = v_current_month
    ) INTO v_task_exists;

    IF NOT v_task_exists THEN
        -- タスクレコードが存在しない場合は作成
        INSERT INTO monthly_reward_tasks (
            user_id, year, month, is_completed, questions_answered, answers, completed_at
        )
        VALUES (
            p_user_id, v_current_year, v_current_month, true,
            jsonb_array_length(p_answers), p_answers, NOW()
        );
    ELSE
        -- 既存のタスクを完了状態に更新
        UPDATE monthly_reward_tasks
        SET
            is_completed = true,
            questions_answered = jsonb_array_length(p_answers),
            answers = p_answers,
            completed_at = NOW(),
            updated_at = NOW()
        WHERE user_id = p_user_id
        AND year = v_current_year
        AND month = v_current_month;
    END IF;

    -- 対応する出金レコードを更新
    -- ⭐ task_completed = true に変更
    -- ⭐ status を 'pending'（送金待ち）に変更
    UPDATE monthly_withdrawals
    SET
        task_completed = true,
        task_completed_at = NOW(),
        status = CASE
            WHEN withdrawal_method IS NOT NULL THEN 'pending'  -- 送金方法設定済み → 送金待ち
            ELSE 'on_hold'  -- 送金方法未設定 → 保留継続
        END,
        updated_at = NOW()
    WHERE user_id = p_user_id
    AND withdrawal_month = v_withdrawal_month;

    RETURN true;
END;
$$;

-- ========================================
-- 実行権限付与
-- ========================================

GRANT EXECUTE ON FUNCTION process_monthly_withdrawals(DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION process_monthly_withdrawals(DATE) TO anon;
GRANT EXECUTE ON FUNCTION complete_reward_task(VARCHAR(6), JSONB) TO authenticated;

-- ========================================
-- 完了メッセージ
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ 月末出金処理関数を作成しました';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '機能:';
    RAISE NOTICE '  - 日本時間での月末判定';
    RAISE NOTICE '  - available_usdt >= 10 のユーザーに出金申請作成';
    RAISE NOTICE '  - ペガサス交換ユーザー（制限中）を除外';
    RAISE NOTICE '  - 初期ステータス: on_hold（タスク未完了）';
    RAISE NOTICE '  - タスク完了時に status を pending に変更';
    RAISE NOTICE '===========================================';
END $$;
