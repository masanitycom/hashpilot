-- ========================================
-- 月末出金に紹介報酬を含める修正
-- ========================================
-- 作成日: 2025-12-17
--
-- 変更内容:
-- 1. affiliate_cycleにwithdrawn_referral_usdtカラム追加
-- 2. process_monthly_withdrawals関数を修正（USDTフェーズなら紹介報酬も含める）
-- 3. complete_withdrawals_batch関数を修正（withdrawn_referral_usdtも更新）
-- ========================================

-- ========================================
-- STEP 1: withdrawn_referral_usdtカラム追加
-- ========================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'affiliate_cycle'
      AND column_name = 'withdrawn_referral_usdt'
  ) THEN
    ALTER TABLE affiliate_cycle
    ADD COLUMN withdrawn_referral_usdt NUMERIC DEFAULT 0;

    RAISE NOTICE '✅ withdrawn_referral_usdtカラムを追加しました';
  ELSE
    RAISE NOTICE '⚠️ withdrawn_referral_usdtカラムは既に存在します';
  END IF;
END $$;

-- ========================================
-- STEP 2: monthly_withdrawalsテーブルに紹介報酬関連カラム追加
-- ========================================
DO $$
BEGIN
  -- personal_amount（個人利益分）
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'monthly_withdrawals'
      AND column_name = 'personal_amount'
  ) THEN
    ALTER TABLE monthly_withdrawals
    ADD COLUMN personal_amount NUMERIC DEFAULT 0;
    RAISE NOTICE '✅ personal_amountカラムを追加しました';
  END IF;

  -- referral_amount（紹介報酬分）
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'monthly_withdrawals'
      AND column_name = 'referral_amount'
  ) THEN
    ALTER TABLE monthly_withdrawals
    ADD COLUMN referral_amount NUMERIC DEFAULT 0;
    RAISE NOTICE '✅ referral_amountカラムを追加しました';
  END IF;
END $$;

-- ========================================
-- STEP 3: process_monthly_withdrawals関数を修正
-- ========================================
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

    -- 出金処理
    -- ⭐ 紹介報酬も含めて計算（USDTフェーズの場合のみ）
    FOR v_user_record IN
        SELECT
            ac.user_id,
            u.email,
            ac.available_usdt,
            ac.cum_usdt,
            ac.phase,
            COALESCE(ac.withdrawn_referral_usdt, 0) as withdrawn_referral_usdt,
            COALESCE(u.coinw_uid, '') as coinw_uid,
            COALESCE(u.nft_receive_address, '') as nft_receive_address,
            u.is_pegasus_exchange,
            u.pegasus_withdrawal_unlock_date,
            -- ⭐ 出金可能な紹介報酬を計算
            CASE
                WHEN ac.phase = 'USDT' THEN
                    GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))
                ELSE
                    0  -- HOLDフェーズは紹介報酬出金不可
            END as withdrawable_referral
        FROM affiliate_cycle ac
        INNER JOIN users u ON ac.user_id = u.user_id
        WHERE
          -- ⭐ 個人利益 + 出金可能紹介報酬 >= 10
          (ac.available_usdt +
            CASE
              WHEN ac.phase = 'USDT' THEN GREATEST(0, ac.cum_usdt - COALESCE(ac.withdrawn_referral_usdt, 0))
              ELSE 0
            END
          ) >= 10
          -- ペガサス交換ユーザーで出金制限期間内のユーザーを除外
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
            v_personal_amount NUMERIC;
            v_referral_amount NUMERIC;
            v_total_withdrawal NUMERIC;
        BEGIN
            -- 個人利益と紹介報酬を分けて記録
            v_personal_amount := v_user_record.available_usdt;
            v_referral_amount := v_user_record.withdrawable_referral;
            v_total_withdrawal := v_personal_amount + v_referral_amount;

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

            -- 出金申請レコードを作成
            INSERT INTO monthly_withdrawals (
                user_id,
                email,
                withdrawal_month,
                total_amount,
                personal_amount,
                referral_amount,
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
                v_total_withdrawal,
                v_personal_amount,
                v_referral_amount,
                v_withdrawal_method,
                v_withdrawal_address,
                v_initial_status,
                false,
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
            v_total_amount := v_total_amount + v_total_withdrawal;
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
                'target_month', v_target_month,
                'includes_referral', true
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
                FORMAT('月末出金処理が完了しました。%s年%s月分 - 出金申請: %s件（総額: $%s、紹介報酬含む）', v_year, v_month, v_processed_count, v_total_amount::TEXT)
        END;
END;
$$;

-- ========================================
-- STEP 4: complete_withdrawals_batch関数を修正
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
BEGIN
    FOREACH v_withdrawal_id IN ARRAY p_withdrawal_ids
    LOOP
        BEGIN
            -- 出金レコードを取得
            SELECT
                mw.user_id,
                mw.total_amount,
                COALESCE(mw.personal_amount, mw.total_amount) as personal_amount,
                COALESCE(mw.referral_amount, 0) as referral_amount
            INTO v_user_id, v_total_amount, v_personal_amount, v_referral_amount
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

            -- available_usdt から個人利益分を減算
            UPDATE affiliate_cycle ac
            SET
                available_usdt = GREATEST(0, ac.available_usdt - v_personal_amount),
                -- ⭐ withdrawn_referral_usdt に紹介報酬出金分を加算
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

-- ========================================
-- 権限付与
-- ========================================
GRANT EXECUTE ON FUNCTION process_monthly_withdrawals(DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION process_monthly_withdrawals(DATE) TO anon;
GRANT EXECUTE ON FUNCTION complete_withdrawals_batch(UUID[]) TO authenticated;

-- ========================================
-- STEP 5: 既存の出金履歴を修正（11月分）
-- ========================================
-- 11月分の出金履歴について、個人利益と紹介報酬を計算して更新

-- まず確認
SELECT '【確認】11月分の既存出金履歴' as section;
SELECT
  mw.user_id,
  mw.total_amount,
  mw.personal_amount,
  mw.referral_amount,
  mw.status,
  mw.withdrawal_month
FROM monthly_withdrawals mw
WHERE mw.withdrawal_month = '2025-11-01'
ORDER BY mw.total_amount DESC
LIMIT 20;

-- 11月分の出金履歴を更新
-- personal_amount = 11月の日利合計
-- referral_amount = total_amount - personal_amount
UPDATE monthly_withdrawals mw
SET
  personal_amount = COALESCE(daily.total_daily_profit, 0),
  referral_amount = mw.total_amount - COALESCE(daily.total_daily_profit, 0)
FROM (
  SELECT
    user_id,
    SUM(daily_profit) as total_daily_profit
  FROM nft_daily_profit
  WHERE date >= '2025-11-01' AND date < '2025-12-01'
  GROUP BY user_id
) daily
WHERE mw.user_id = daily.user_id
  AND mw.withdrawal_month = '2025-11-01'
  AND (mw.personal_amount IS NULL OR mw.personal_amount = 0 OR mw.personal_amount = mw.total_amount);

-- personal_amount がまだ NULL の場合（日利データがない場合）は total_amount をセット
UPDATE monthly_withdrawals
SET
  personal_amount = total_amount,
  referral_amount = 0
WHERE withdrawal_month = '2025-11-01'
  AND personal_amount IS NULL;

-- ========================================
-- STEP 6: withdrawn_referral_usdtを更新（完了済み出金分）
-- ========================================
-- 完了済みの出金について、referral_amount分をwithdrawn_referral_usdtに加算

UPDATE affiliate_cycle ac
SET
  withdrawn_referral_usdt = COALESCE(ac.withdrawn_referral_usdt, 0) + COALESCE(mw.total_referral, 0)
FROM (
  SELECT
    user_id,
    SUM(COALESCE(referral_amount, 0)) as total_referral
  FROM monthly_withdrawals
  WHERE status = 'completed'
    AND referral_amount > 0
  GROUP BY user_id
) mw
WHERE ac.user_id = mw.user_id;

-- ========================================
-- 確認
-- ========================================
SELECT '✅ 月末出金に紹介報酬を含める修正が完了しました' as status;
SELECT '  - affiliate_cycle.withdrawn_referral_usdt カラム追加' as detail1;
SELECT '  - monthly_withdrawals.personal_amount, referral_amount カラム追加' as detail2;
SELECT '  - process_monthly_withdrawals 関数修正（USDTフェーズなら紹介報酬も含める）' as detail3;
SELECT '  - complete_withdrawals_batch 関数修正（withdrawn_referral_usdtも更新）' as detail4;
SELECT '  - 既存出金履歴（11月分）の personal_amount, referral_amount を更新' as detail5;
SELECT '  - 完了済み出金の withdrawn_referral_usdt を更新' as detail6;

-- 更新後の確認
SELECT '【確認】更新後の11月分出金履歴' as section;
SELECT
  mw.user_id,
  mw.total_amount,
  mw.personal_amount,
  mw.referral_amount,
  mw.status
FROM monthly_withdrawals mw
WHERE mw.withdrawal_month = '2025-11-01'
ORDER BY mw.total_amount DESC
LIMIT 20;

SELECT '【確認】withdrawn_referral_usdt更新後' as section;
SELECT
  user_id,
  cum_usdt,
  withdrawn_referral_usdt,
  phase
FROM affiliate_cycle
WHERE withdrawn_referral_usdt > 0
ORDER BY withdrawn_referral_usdt DESC
LIMIT 20;
