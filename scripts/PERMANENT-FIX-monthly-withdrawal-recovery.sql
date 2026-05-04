-- ========================================
-- 月末出金処理の恒久対策
-- 漏れを完全に防ぐための仕組み
-- ========================================
-- 目的:
--   1. 過払い債務でavailable_usdtがマイナスのユーザーも漏らさない
--   2. check_monthly_integrityの偽陽性（運用開始前ユーザー）を解消
--   3. 月末処理後に自動で漏れを補完
-- ========================================

-- ========================================
-- PART 1: check_monthly_integrity 改良
-- Check1の偽陽性（運用開始前ユーザー）を除外
-- ========================================

CREATE OR REPLACE FUNCTION check_monthly_integrity(
    p_year INTEGER,
    p_month INTEGER
)
RETURNS TABLE(
    check_name TEXT,
    check_result TEXT,
    affected_count INTEGER,
    details JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_target_month DATE;
    v_month_end DATE;
    v_year_month TEXT;
    v_count INTEGER;
    v_details JSONB;
BEGIN
    v_target_month := make_date(p_year, p_month, 1);
    v_month_end := (v_target_month + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
    v_year_month := format('%s-%s', p_year, LPAD(p_month::TEXT, 2, '0'));

    -- ========================================
    -- CHECK 1: 出金レコード漏れ
    -- 改良: operation_start_date <= 月末日のユーザーのみ対象
    -- ========================================
    SELECT COUNT(*), COALESCE(jsonb_agg(jsonb_build_object(
        'user_id', sub.user_id,
        'email', sub.email,
        'available_usdt', sub.available_usdt
    )), '[]'::jsonb)
    INTO v_count, v_details
    FROM (
        SELECT ac.user_id, u.email, ac.available_usdt
        FROM affiliate_cycle ac
        JOIN users u ON ac.user_id = u.user_id
        WHERE ac.available_usdt > 0
          AND u.is_active_investor = true
          AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
          -- 運用開始前ユーザーは対象外
          AND u.operation_start_date IS NOT NULL
          AND u.operation_start_date <= v_month_end
          AND NOT EXISTS (
              SELECT 1 FROM monthly_withdrawals mw
              WHERE mw.user_id = ac.user_id
                AND mw.withdrawal_month = v_target_month
          )
    ) sub;

    check_name := '出金レコード漏れ';
    IF v_count = 0 THEN check_result := 'OK'; ELSE check_result := 'NG'; END IF;
    affected_count := v_count;
    details := v_details;
    RETURN NEXT;

    -- CHECK 2: 紹介報酬漏れ(L1)
    SELECT COUNT(*), COALESCE(jsonb_agg(jsonb_build_object(
        'parent_id', sub.parent_id,
        'child_id', sub.child_id,
        'expected_amount', sub.expected_amount
    )), '[]'::jsonb)
    INTO v_count, v_details
    FROM (
        SELECT
            u.user_id as parent_id,
            child.user_id as child_id,
            ROUND(SUM(ndp.daily_profit) * 0.20, 2) as expected_amount
        FROM users u
        JOIN users child ON child.referrer_user_id = u.user_id
        JOIN nft_daily_profit ndp ON ndp.user_id = child.user_id
        WHERE ndp.date >= v_target_month
          AND ndp.date < (v_target_month + INTERVAL '1 month')
          AND u.has_approved_nft = true
          AND u.operation_start_date IS NOT NULL
          AND u.operation_start_date <= v_month_end
          AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
          AND child.has_approved_nft = true
          AND child.operation_start_date IS NOT NULL
          AND child.operation_start_date <= v_month_end
        GROUP BY u.user_id, child.user_id
        HAVING SUM(ndp.daily_profit) > 0
          AND NOT EXISTS (
              SELECT 1 FROM monthly_referral_profit mrp
              WHERE mrp.user_id = u.user_id
                AND mrp.child_user_id = child.user_id
                AND mrp.year_month = v_year_month
                AND mrp.referral_level = 1
          )
    ) sub;

    check_name := '紹介報酬漏れ(L1)';
    IF v_count = 0 THEN check_result := 'OK'; ELSE check_result := 'NG'; END IF;
    affected_count := v_count;
    details := v_details;
    RETURN NEXT;

    -- CHECK 3: available_usdt整合性（HOLD/Auto-NFTロック考慮版）
    SELECT COUNT(*), COALESCE(jsonb_agg(jsonb_build_object(
        'user_id', sub.user_id,
        'expected', sub.expected_available,
        'actual', sub.actual_available,
        'difference', sub.difference,
        'auto_nft_lock', sub.auto_nft_lock,
        'hold_lock', sub.hold_lock
    )), '[]'::jsonb)
    INTO v_count, v_details
    FROM (
        SELECT
            ac.user_id,
            (ac.auto_nft_count * 1100) as auto_nft_lock,
            GREATEST(0, ac.cum_usdt - 1100) as hold_lock,
            ROUND((
                COALESCE(e.total_profit, 0)
                + COALESCE(r.total_referral, 0)
                - COALESCE(w.total_withdrawn, 0)
                - (ac.auto_nft_count * 1100)
                - GREATEST(0, ac.cum_usdt - 1100)
            )::numeric, 2) as expected_available,
            ROUND(ac.available_usdt::numeric, 2) as actual_available,
            ROUND((
                ac.available_usdt - (
                    COALESCE(e.total_profit, 0)
                    + COALESCE(r.total_referral, 0)
                    - COALESCE(w.total_withdrawn, 0)
                    - (ac.auto_nft_count * 1100)
                    - GREATEST(0, ac.cum_usdt - 1100)
                )
            )::numeric, 2) as difference
        FROM affiliate_cycle ac
        LEFT JOIN (
            SELECT user_id, SUM(daily_profit) as total_profit
            FROM nft_daily_profit GROUP BY user_id
        ) e ON ac.user_id = e.user_id
        LEFT JOIN (
            SELECT user_id, SUM(profit_amount) as total_referral
            FROM monthly_referral_profit GROUP BY user_id
        ) r ON ac.user_id = r.user_id
        LEFT JOIN (
            SELECT user_id, SUM(total_amount) as total_withdrawn
            FROM monthly_withdrawals mw2 WHERE mw2.status = 'completed'
            GROUP BY user_id
        ) w ON ac.user_id = w.user_id
        WHERE ac.available_usdt > 0
          AND ABS(
              ac.available_usdt - (
                  COALESCE(e.total_profit, 0)
                  + COALESCE(r.total_referral, 0)
                  - COALESCE(w.total_withdrawn, 0)
                  - (ac.auto_nft_count * 1100)
                  - GREATEST(0, ac.cum_usdt - 1100)
              )
          ) > 10
    ) sub;

    check_name := 'available_usdt整合性(差>$10)';
    IF v_count = 0 THEN check_result := 'OK'; ELSE check_result := 'NG'; END IF;
    affected_count := v_count;
    details := v_details;
    RETURN NEXT;

    -- CHECK 4: NFTカウント整合性
    SELECT COUNT(*), COALESCE(jsonb_agg(jsonb_build_object(
        'user_id', sub.user_id,
        'cycle_total', sub.cycle_total,
        'actual_total', sub.actual_total
    )), '[]'::jsonb)
    INTO v_count, v_details
    FROM (
        SELECT
            ac.user_id,
            ac.total_nft_count as cycle_total,
            COUNT(nm.id) FILTER (WHERE nm.buyback_date IS NULL) as actual_total
        FROM affiliate_cycle ac
        LEFT JOIN nft_master nm ON ac.user_id = nm.user_id
        GROUP BY ac.user_id, ac.total_nft_count
        HAVING ac.total_nft_count != COUNT(nm.id) FILTER (WHERE nm.buyback_date IS NULL)
    ) sub;

    check_name := 'NFTカウント整合性';
    IF v_count = 0 THEN check_result := 'OK'; ELSE check_result := 'NG'; END IF;
    affected_count := v_count;
    details := v_details;
    RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION check_monthly_integrity(INTEGER, INTEGER) TO authenticated;

-- ========================================
-- PART 2: 月末漏れ自動補完関数
-- process_monthly_withdrawals の後に実行する
-- マイナスavailable_usdt等で漏れたユーザーを救済
-- ========================================

CREATE OR REPLACE FUNCTION recover_missing_monthly_withdrawals(
    p_target_date DATE  -- 例: '2026-04-30'
)
RETURNS TABLE(
    user_id VARCHAR,
    email TEXT,
    personal_amount NUMERIC,
    referral_amount NUMERIC,
    total_amount NUMERIC,
    old_available_usdt NUMERIC,
    new_available_usdt NUMERIC,
    action TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_target_month DATE;
    v_month_end DATE;
    v_year_month TEXT;
    v_user RECORD;
    v_personal NUMERIC;
    v_referral NUMERIC;
    v_total NUMERIC;
    v_old_available NUMERIC;
    v_new_available NUMERIC;
BEGIN
    v_target_month := DATE_TRUNC('month', p_target_date)::DATE;
    v_month_end := (v_target_month + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
    v_year_month := TO_CHAR(v_target_month, 'YYYY-MM');

    -- 漏れユーザーを検出して補完
    FOR v_user IN
        SELECT
            u.user_id,
            u.email,
            u.coinw_uid,
            u.nft_receive_address,
            ac.available_usdt
        FROM users u
        JOIN affiliate_cycle ac ON u.user_id = ac.user_id
        WHERE u.is_active_investor = true
          AND u.has_approved_nft = true
          AND (u.is_pegasus_exchange = FALSE OR u.is_pegasus_exchange IS NULL)
          AND u.operation_start_date IS NOT NULL
          AND u.operation_start_date <= v_month_end
          AND NOT EXISTS (
              SELECT 1 FROM monthly_withdrawals mw
              WHERE mw.user_id = u.user_id
                AND mw.withdrawal_month = v_target_month
          )
    LOOP
        -- 当月日利合計
        SELECT COALESCE(SUM(daily_profit), 0)
        INTO v_personal
        FROM nft_daily_profit
        WHERE nft_daily_profit.user_id = v_user.user_id
          AND date >= v_target_month
          AND date < v_target_month + INTERVAL '1 month';

        -- 当月紹介報酬合計
        SELECT COALESCE(SUM(profit_amount), 0)
        INTO v_referral
        FROM monthly_referral_profit
        WHERE monthly_referral_profit.user_id = v_user.user_id
          AND year_month = v_year_month;

        v_total := v_personal + v_referral;

        -- 当月収入が0以下ならスキップ
        IF v_total <= 0 THEN
            CONTINUE;
        END IF;

        v_old_available := v_user.available_usdt;

        -- available_usdtがtotal_amount未満なら補正（過払い債務write-off）
        IF v_user.available_usdt < v_total THEN
            UPDATE affiliate_cycle
            SET available_usdt = v_total,
                last_updated = NOW()
            WHERE affiliate_cycle.user_id = v_user.user_id;
            v_new_available := v_total;
        ELSE
            v_new_available := v_user.available_usdt;
        END IF;

        -- monthly_withdrawalsレコード作成
        INSERT INTO monthly_withdrawals (
            user_id, email, withdrawal_month, status,
            personal_amount, referral_amount, total_amount,
            task_completed, withdrawal_method, withdrawal_address,
            notes, created_at, updated_at
        )
        VALUES (
            v_user.user_id,
            v_user.email,
            v_target_month,
            'on_hold',
            v_personal,
            v_referral,
            v_total,
            false,
            CASE
                WHEN v_user.coinw_uid IS NOT NULL THEN 'coinw'
                WHEN v_user.nft_receive_address IS NOT NULL THEN 'bep20'
                ELSE NULL
            END,
            COALESCE(v_user.coinw_uid, v_user.nft_receive_address),
            CASE
                WHEN v_old_available < v_total
                THEN '漏れ補完: 過払い債務をwrite-offし当月収入で補填'
                ELSE '漏れ補完: 月末処理から漏れていたため追加'
            END,
            NOW(),
            NOW()
        );

        -- 結果を返す
        RETURN QUERY SELECT
            v_user.user_id,
            v_user.email,
            v_personal,
            v_referral,
            v_total,
            v_old_available,
            v_new_available,
            CASE
                WHEN v_old_available < v_total THEN 'WRITE_OFF'
                ELSE 'ADDED'
            END;
    END LOOP;
END;
$$;

GRANT EXECUTE ON FUNCTION recover_missing_monthly_withdrawals(DATE) TO authenticated;

-- ========================================
-- PART 3: 月末処理の総合関数
-- process_monthly_withdrawals + 自動補完 + 整合性チェック
-- ========================================

CREATE OR REPLACE FUNCTION run_monthly_close(
    p_target_date DATE  -- 月末日（例: '2026-04-30'）
)
RETURNS TABLE(
    step_name TEXT,
    step_result TEXT,
    detail JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_target_month DATE;
    v_year INTEGER;
    v_month INTEGER;
    v_main_result RECORD;
    v_recover_count INTEGER := 0;
    v_recover_total NUMERIC := 0;
    v_recover_details JSONB;
    v_check_result RECORD;
    v_check_results JSONB := '[]'::jsonb;
BEGIN
    v_target_month := DATE_TRUNC('month', p_target_date)::DATE;
    v_year := EXTRACT(YEAR FROM v_target_month)::INTEGER;
    v_month := EXTRACT(MONTH FROM v_target_month)::INTEGER;

    -- STEP 1: 通常の月末処理
    SELECT INTO v_main_result *
    FROM process_monthly_withdrawals(p_target_date);

    step_name := '1. process_monthly_withdrawals';
    step_result := 'COMPLETED';
    detail := jsonb_build_object(
        'processed_count', v_main_result.processed_count,
        'total_amount', v_main_result.total_amount,
        'message', v_main_result.message
    );
    RETURN NEXT;

    -- STEP 2: 漏れ補完
    SELECT
        COUNT(*),
        COALESCE(SUM(rmw.total_amount), 0),
        COALESCE(jsonb_agg(jsonb_build_object(
            'user_id', rmw.user_id,
            'email', rmw.email,
            'total', rmw.total_amount,
            'old_available', rmw.old_available_usdt,
            'action', rmw.action
        )), '[]'::jsonb)
    INTO v_recover_count, v_recover_total, v_recover_details
    FROM recover_missing_monthly_withdrawals(p_target_date) rmw;

    step_name := '2. recover_missing_monthly_withdrawals';
    step_result := CASE WHEN v_recover_count = 0 THEN 'NO_RECOVERY' ELSE 'RECOVERED' END;
    detail := jsonb_build_object(
        'recovered_count', v_recover_count,
        'recovered_total', v_recover_total,
        'users', v_recover_details
    );
    RETURN NEXT;

    -- STEP 3: 整合性チェック
    FOR v_check_result IN
        SELECT * FROM check_monthly_integrity(v_year, v_month)
    LOOP
        v_check_results := v_check_results || jsonb_build_object(
            'check_name', v_check_result.check_name,
            'check_result', v_check_result.check_result,
            'affected_count', v_check_result.affected_count,
            'details', v_check_result.details
        );
    END LOOP;

    step_name := '3. check_monthly_integrity';
    step_result := 'COMPLETED';
    detail := v_check_results;
    RETURN NEXT;
END;
$$;

GRANT EXECUTE ON FUNCTION run_monthly_close(DATE) TO authenticated;

-- ========================================
-- 使い方
-- ========================================
-- 月末処理（毎月実行）:
--   SELECT * FROM run_monthly_close('2026-05-31');
--
-- これを実行すると以下が自動で行われる:
--   1. process_monthly_withdrawals 実行
--   2. 漏れたユーザーの自動補完（マイナスavailable_usdt等）
--   3. 整合性チェック実行
--
-- 個別実行も可能:
--   SELECT * FROM recover_missing_monthly_withdrawals('2026-05-31');
--   SELECT * FROM check_monthly_integrity(2026, 5);
-- ========================================

SELECT '✅ 月末出金処理の恒久対策を導入しました' as status;
