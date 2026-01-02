-- ========================================
-- process_monthly_withdrawals関数を修正
-- personal_amountとreferral_amountを正しく設定するように
-- ========================================
-- 実行日: 2026-01-01
--
-- 問題: 現在の関数はtotal_amountのみを設定し、
--       personal_amountとreferral_amountを設定していない
-- 修正: 出金レコード作成時に内訳も計算して保存
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
    -- 内訳用変数
    v_personal_amount NUMERIC;
    v_referral_amount NUMERIC;
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
        -- ⭐ 個人利益を計算（nft_daily_profitから当月分）
        SELECT COALESCE(SUM(daily_profit), 0)
        INTO v_personal_amount
        FROM nft_daily_profit
        WHERE user_id = v_user_record.user_id
          AND date >= v_target_month
          AND date < (v_target_month + INTERVAL '1 month');

        -- ⭐ 紹介報酬を計算（user_referral_profit_monthlyから当月分）
        SELECT COALESCE(SUM(profit_amount), 0)
        INTO v_referral_amount
        FROM user_referral_profit_monthly
        WHERE user_id = v_user_record.user_id
          AND year = v_year
          AND month = v_month;

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
                personal_amount,      -- ⭐ 個人利益
                referral_amount,      -- ⭐ 紹介報酬
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
                v_personal_amount,    -- ⭐ 個人利益
                v_referral_amount,    -- ⭐ 紹介報酬
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
-- 実行権限付与
-- ========================================

GRANT EXECUTE ON FUNCTION process_monthly_withdrawals(DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION process_monthly_withdrawals(DATE) TO anon;

-- ========================================
-- 完了メッセージ
-- ========================================

DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ 月末出金処理関数を更新しました';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '変更点:';
    RAISE NOTICE '  - personal_amount: nft_daily_profitから計算';
    RAISE NOTICE '  - referral_amount: user_referral_profit_monthlyから計算';
    RAISE NOTICE '===========================================';
END $$;
