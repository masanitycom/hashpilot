-- ===============================================
-- 運用開始日未設定ユーザーの日利・紹介報酬を修正
-- ===============================================
--
-- 問題:
--   process_daily_yield_with_cycles関数で、operation_start_date IS NULL のユーザーも
--   日利と紹介報酬の対象になっていた
--
-- 原因:
--   条件: (u.operation_start_date IS NULL OR u.operation_start_date <= p_date)
--
-- 修正:
--   条件: u.operation_start_date IS NOT NULL AND u.operation_start_date <= p_date
--
-- 影響:
--   - 38名のユーザーが合計$340.902の日利を誤って受け取っている
--   - 紹介報酬も同様に誤って支払われている可能性
--
-- 実行日: 2025-11-13
-- ===============================================

-- ? STEP 1: 現状確認（実行前）
SELECT
    'BEFORE FIX' as check_point,
    COUNT(DISTINCT udp.user_id) as affected_users,
    COALESCE(SUM(udp.daily_profit), 0) as total_incorrect_profit,
    MIN(udp.date) as first_date,
    MAX(udp.date) as last_date
FROM user_daily_profit udp
INNER JOIN users u ON udp.user_id = u.user_id
WHERE u.operation_start_date IS NULL;

-- ? STEP 2: 関数の修正
CREATE OR REPLACE FUNCTION public.process_daily_yield_with_cycles(
    p_date date,
    p_yield_rate numeric,
    p_margin_rate numeric DEFAULT 30.0,
    p_is_test_mode boolean DEFAULT true,
    p_skip_validation boolean DEFAULT false
)
RETURNS TABLE(
    status text,
    total_users integer,
    total_user_profit numeric,
    total_company_profit numeric,
    cycle_updates integer,
    auto_nft_purchases integer,
    referral_rewards_processed integer,
    monthly_withdrawals_processed integer,
    message text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_user_count INTEGER := 0;
    v_total_user_profit NUMERIC := 0;
    v_total_company_profit NUMERIC := 0;
    v_cycle_updates INTEGER := 0;
    v_auto_purchases INTEGER := 0;
    v_referral_count INTEGER := 0;
    v_monthly_withdrawal_count INTEGER := 0;
    v_user_rate NUMERIC;
    v_after_margin NUMERIC;
    v_nft_record RECORD;
    v_nft_profit NUMERIC;
    v_company_profit NUMERIC;
    v_user_record RECORD;
    v_user_profit NUMERIC;
    v_base_amount NUMERIC;
    v_referral_profit NUMERIC;
    v_level_rate NUMERIC;
    v_child_record RECORD;
    v_is_month_end BOOLEAN;
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ;
    v_processing_time INTERVAL;
BEGIN
    v_start_time := NOW();
    v_is_month_end := is_month_end();

    -- パーセント値を割合に変換
    v_after_margin := (p_yield_rate / 100) * (1 - p_margin_rate / 100);
    v_user_rate := v_after_margin * 0.6;

    IF NOT p_is_test_mode THEN
        INSERT INTO daily_yield_log (date, yield_rate, margin_rate, user_rate, created_at)
        VALUES (p_date, p_yield_rate, p_margin_rate, v_user_rate, NOW())
        ON CONFLICT (date) DO UPDATE SET
            yield_rate = EXCLUDED.yield_rate,
            margin_rate = EXCLUDED.margin_rate,
            user_rate = EXCLUDED.user_rate,
            created_at = NOW();
    END IF;

    -- ✅ STEP 1: 各NFTの日利を計算（個人利益 - ペガサス交換ユーザーを除外）
    FOR v_nft_record IN
        SELECT nm.id as nft_id, nm.user_id, nm.nft_type, nm.nft_value
        FROM nft_master nm
        INNER JOIN users u ON nm.user_id = u.user_id
        WHERE nm.buyback_date IS NULL
        AND COALESCE(u.is_pegasus_exchange, FALSE) = FALSE  -- ペガサス除外
    LOOP
        v_nft_profit := v_nft_record.nft_value * v_user_rate;
        v_company_profit := v_nft_record.nft_value * (p_yield_rate / 100) - v_nft_profit;
        v_total_user_profit := v_total_user_profit + v_nft_profit;
        v_total_company_profit := v_total_company_profit + v_company_profit;

        IF NOT p_is_test_mode THEN
            INSERT INTO nft_daily_profit (nft_id, user_id, date, daily_profit, yield_rate, created_at)
            VALUES (v_nft_record.nft_id, v_nft_record.user_id, p_date, v_nft_profit, p_yield_rate, NOW())
            ON CONFLICT (nft_id, date) DO UPDATE SET
                daily_profit = EXCLUDED.daily_profit, yield_rate = EXCLUDED.yield_rate, created_at = NOW();
        END IF;
    END LOOP;

    -- ✅ STEP 2: ユーザーごとに集計（個人利益 - 運用開始日チェック強化）
    FOR v_user_record IN
        SELECT u.user_id, u.has_approved_nft, u.operation_start_date,
               COALESCE(SUM(nm.nft_value), 0) as total_nft_value,
               COALESCE(ac.cum_usdt, 0) as cum_usdt, COALESCE(ac.available_usdt, 0) as available_usdt,
               COALESCE(ac.phase, 'USDT') as phase, COALESCE(ac.auto_nft_count, 0) as auto_nft_count,
               COALESCE(ac.manual_nft_count, 0) as manual_nft_count
        FROM users u
        LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
        LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
        WHERE u.has_approved_nft = true
        -- ⭐ 修正箇所: operation_start_date IS NOT NULL AND 運用開始日経過済み
        AND u.operation_start_date IS NOT NULL
        AND u.operation_start_date <= p_date
        AND COALESCE(u.is_pegasus_exchange, FALSE) = FALSE  -- ペガサス除外
        GROUP BY u.user_id, u.has_approved_nft, u.operation_start_date,
                 ac.cum_usdt, ac.available_usdt, ac.phase, ac.auto_nft_count, ac.manual_nft_count
    LOOP
        v_user_count := v_user_count + 1;
        v_base_amount := v_user_record.total_nft_value;
        v_user_profit := v_base_amount * v_user_rate;

        IF NOT p_is_test_mode THEN
            -- available_usdtに個人利益を加算（マイナスも含む）
            INSERT INTO affiliate_cycle (user_id, cum_usdt, available_usdt, phase, auto_nft_count, manual_nft_count, created_at, updated_at)
            VALUES (v_user_record.user_id, 0, v_user_profit, 'USDT', 0, 0, NOW(), NOW())
            ON CONFLICT (user_id) DO UPDATE SET
                available_usdt = affiliate_cycle.available_usdt + EXCLUDED.available_usdt, updated_at = NOW();
            v_cycle_updates := v_cycle_updates + 1;
        END IF;
    END LOOP;

    -- ✅ STEP 3: 紹介報酬（運用開始日チェック強化、マイナス日利時は0）
    IF p_yield_rate > 0 THEN
        FOR v_user_record IN
            SELECT u.user_id, u.has_approved_nft, u.operation_start_date,
                   COALESCE(SUM(nm.nft_value), 0) as total_nft_value
            FROM users u
            LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
            WHERE u.has_approved_nft = true
            -- ⭐ 修正箇所: operation_start_date IS NOT NULL AND 運用開始日経過済み
            AND u.operation_start_date IS NOT NULL
            AND u.operation_start_date <= p_date
            -- ペガサス交換ユーザーも紹介報酬の対象（紹介者が受け取る）
            GROUP BY u.user_id, u.has_approved_nft, u.operation_start_date
        LOOP
            v_user_profit := v_user_record.total_nft_value * v_user_rate;

            -- レベル1: 20%
            FOR v_child_record IN
                SELECT DISTINCT u2.user_id as parent_id
                FROM users u2
                WHERE u2.referrer_user_id = v_user_record.user_id
                AND u2.has_approved_nft = true
                AND u2.operation_start_date IS NOT NULL
                AND u2.operation_start_date <= p_date
            LOOP
                v_referral_profit := v_user_profit * 0.20;
                IF NOT p_is_test_mode THEN
                    INSERT INTO user_referral_profit (user_id, child_user_id, date, referral_level, profit_amount, created_at)
                    VALUES (v_child_record.parent_id, v_user_record.user_id, p_date, 1, v_referral_profit, NOW())
                    ON CONFLICT (user_id, date, referral_level, child_user_id) DO UPDATE SET
                        profit_amount = EXCLUDED.profit_amount, created_at = NOW();

                    INSERT INTO affiliate_cycle (user_id, cum_usdt, available_usdt, phase, auto_nft_count, manual_nft_count, created_at, updated_at)
                    VALUES (v_child_record.parent_id, v_referral_profit, 0, 'USDT', 0, 0, NOW(), NOW())
                    ON CONFLICT (user_id) DO UPDATE SET
                        cum_usdt = affiliate_cycle.cum_usdt + EXCLUDED.cum_usdt, updated_at = NOW();
                END IF;
                v_referral_count := v_referral_count + 1;
            END LOOP;

            -- レベル2: 10%
            FOR v_child_record IN
                SELECT DISTINCT u3.user_id as parent_id
                FROM users u2
                INNER JOIN users u3 ON u2.referrer_user_id = u3.user_id
                WHERE u2.referrer_user_id = v_user_record.user_id
                AND u3.has_approved_nft = true
                AND u3.operation_start_date IS NOT NULL
                AND u3.operation_start_date <= p_date
            LOOP
                v_referral_profit := v_user_profit * 0.10;
                IF NOT p_is_test_mode THEN
                    INSERT INTO user_referral_profit (user_id, child_user_id, date, referral_level, profit_amount, created_at)
                    VALUES (v_child_record.parent_id, v_user_record.user_id, p_date, 2, v_referral_profit, NOW())
                    ON CONFLICT (user_id, date, referral_level, child_user_id) DO UPDATE SET
                        profit_amount = EXCLUDED.profit_amount, created_at = NOW();

                    INSERT INTO affiliate_cycle (user_id, cum_usdt, available_usdt, phase, auto_nft_count, manual_nft_count, created_at, updated_at)
                    VALUES (v_child_record.parent_id, v_referral_profit, 0, 'USDT', 0, 0, NOW(), NOW())
                    ON CONFLICT (user_id) DO UPDATE SET
                        cum_usdt = affiliate_cycle.cum_usdt + EXCLUDED.cum_usdt, updated_at = NOW();
                END IF;
                v_referral_count := v_referral_count + 1;
            END LOOP;

            -- レベル3: 5%
            FOR v_child_record IN
                SELECT DISTINCT u4.user_id as parent_id
                FROM users u2
                INNER JOIN users u3 ON u2.referrer_user_id = u3.user_id
                INNER JOIN users u4 ON u3.referrer_user_id = u4.user_id
                WHERE u2.referrer_user_id = v_user_record.user_id
                AND u4.has_approved_nft = true
                AND u4.operation_start_date IS NOT NULL
                AND u4.operation_start_date <= p_date
            LOOP
                v_referral_profit := v_user_profit * 0.05;
                IF NOT p_is_test_mode THEN
                    INSERT INTO user_referral_profit (user_id, child_user_id, date, referral_level, profit_amount, created_at)
                    VALUES (v_child_record.parent_id, v_user_record.user_id, p_date, 3, v_referral_profit, NOW())
                    ON CONFLICT (user_id, date, referral_level, child_user_id) DO UPDATE SET
                        profit_amount = EXCLUDED.profit_amount, created_at = NOW();

                    INSERT INTO affiliate_cycle (user_id, cum_usdt, available_usdt, phase, auto_nft_count, manual_nft_count, created_at, updated_at)
                    VALUES (v_child_record.parent_id, v_referral_profit, 0, 'USDT', 0, 0, NOW(), NOW())
                    ON CONFLICT (user_id) DO UPDATE SET
                        cum_usdt = affiliate_cycle.cum_usdt + EXCLUDED.cum_usdt, updated_at = NOW();
                END IF;
                v_referral_count := v_referral_count + 1;
            END LOOP;
        END LOOP;
    END IF;

    -- STEP 4: サイクル判定と自動NFT付与
    IF NOT p_is_test_mode THEN
        FOR v_user_record IN
            SELECT user_id, cum_usdt, auto_nft_count
            FROM affiliate_cycle
            WHERE cum_usdt >= 2200
        LOOP
            INSERT INTO nft_master (user_id, nft_type, nft_value, purchase_date, is_auto_purchase, cycle_number, created_at)
            VALUES (v_user_record.user_id, 'standard', 1000, p_date, TRUE, v_user_record.auto_nft_count + 1, NOW());

            INSERT INTO purchases (user_id, nft_quantity, amount_usd, payment_status, admin_approved,
                                   is_auto_purchase, cycle_number_at_purchase, created_at)
            VALUES (v_user_record.user_id, 1, 1100, 'completed', TRUE, TRUE, v_user_record.auto_nft_count + 1, NOW());

            UPDATE affiliate_cycle
            SET cum_usdt = cum_usdt - 2200, available_usdt = available_usdt + 1100,
                auto_nft_count = auto_nft_count + 1,
                phase = CASE WHEN (cum_usdt - 2200) >= 1100 THEN 'HOLD' ELSE 'USDT' END,
                updated_at = NOW()
            WHERE user_id = v_user_record.user_id;

            v_auto_purchases := v_auto_purchases + 1;
        END LOOP;
    END IF;

    -- STEP 5: 月末出金処理
    IF v_is_month_end AND NOT p_is_test_mode THEN
        SELECT COUNT(*) INTO v_monthly_withdrawal_count
        FROM process_monthly_withdrawals(p_date);
    END IF;

    v_end_time := NOW();
    v_processing_time := v_end_time - v_start_time;

    RETURN QUERY SELECT
        'success'::text, v_user_count, v_total_user_profit, v_total_company_profit,
        v_cycle_updates, v_auto_purchases, v_referral_count, v_monthly_withdrawal_count,
        format('✅ 処理完了（運用開始日チェック修正版）: ユーザー数=%s, サイクル更新=%s, 自動NFT付与=%s, 紹介報酬=%s, 月次出金=%s, 処理時間=%s',
            v_user_count, v_cycle_updates, v_auto_purchases, v_referral_count,
            v_monthly_withdrawal_count, v_processing_time)::text;
END;
$function$;

-- ? STEP 3: 修正後の確認
SELECT
    'AFTER FIX' as check_point,
    '関数修正完了' as status,
    '運用開始日未設定のユーザーは今後日利対象外' as note;

-- ? STEP 4: 誤って支払われた日利の確認（削除は慎重に）
-- ⚠️ 注意: 以下のクエリは確認用。削除する前に必ずバックアップを取ること
SELECT
    u.user_id,
    u.email,
    u.operation_start_date,
    COUNT(DISTINCT udp.date) as days_count,
    COALESCE(SUM(udp.daily_profit), 0) as total_incorrect_profit,
    MIN(udp.date) as first_date,
    MAX(udp.date) as last_date
FROM user_daily_profit udp
INNER JOIN users u ON udp.user_id = u.user_id
WHERE u.operation_start_date IS NULL
GROUP BY u.user_id, u.email, u.operation_start_date
ORDER BY total_incorrect_profit DESC;
