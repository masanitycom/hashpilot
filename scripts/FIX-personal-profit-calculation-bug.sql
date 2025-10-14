-- ========================================
-- 修正: 個人配当計算のバグ
-- 問題: STEP2で total_nft_count * 1000 で再計算しているが、
--       STEP1で既に計算済みの nft_daily_profit を使うべき
-- ========================================

CREATE OR REPLACE FUNCTION process_daily_yield_with_cycles(
    p_date DATE,
    p_yield_rate NUMERIC,
    p_margin_rate NUMERIC DEFAULT 30.0,
    p_is_test_mode BOOLEAN DEFAULT TRUE,
    p_skip_validation BOOLEAN DEFAULT FALSE
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
AS $$
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
    v_user_record RECORD;
    v_nft_record RECORD;
    v_user_profit NUMERIC;
    v_nft_profit NUMERIC;
    v_company_profit NUMERIC;
    v_new_cum_usdt NUMERIC;
    v_new_available_usdt NUMERIC;
    v_auto_nft_count INTEGER;
    v_next_nft_sequence INTEGER;
    v_start_time TIMESTAMP;
    v_is_month_end BOOLEAN;
    v_current_cycle_number INTEGER;
BEGIN
    v_start_time := NOW();

    -- 月末判定（日本時間）
    v_is_month_end := is_month_end();

    -- 利率計算
    v_after_margin := p_yield_rate * (1 - p_margin_rate / 100);
    v_user_rate := v_after_margin * 0.6;

    -- テストモードでない場合のみ daily_yield_log に記録
    IF NOT p_is_test_mode THEN
        INSERT INTO daily_yield_log (date, yield_rate, margin_rate, user_rate, created_at)
        VALUES (p_date, p_yield_rate, p_margin_rate, v_user_rate, NOW())
        ON CONFLICT (date) DO UPDATE SET
            yield_rate = EXCLUDED.yield_rate,
            margin_rate = EXCLUDED.margin_rate,
            user_rate = EXCLUDED.user_rate,
            created_at = NOW();
    END IF;

    -- ⭐ STEP 1: 各NFTの日利を計算（運用開始済みユーザーのみ）
    FOR v_nft_record IN
        SELECT
            nm.id as nft_id,
            nm.user_id,
            nm.nft_type,
            nm.nft_value
        FROM nft_master nm
        INNER JOIN users u ON nm.user_id = u.user_id
        WHERE nm.buyback_date IS NULL
          AND u.operation_start_date IS NOT NULL
          AND u.operation_start_date <= p_date
    LOOP
        v_nft_profit := v_nft_record.nft_value * v_user_rate;
        v_company_profit := v_nft_record.nft_value * p_yield_rate - v_nft_profit;

        v_total_user_profit := v_total_user_profit + v_nft_profit;
        v_total_company_profit := v_total_company_profit + v_company_profit;

        IF NOT p_is_test_mode THEN
            INSERT INTO nft_daily_profit (
                nft_id, user_id, date, daily_profit, yield_rate, created_at
            )
            VALUES (
                v_nft_record.nft_id, v_nft_record.user_id, p_date,
                v_nft_profit, p_yield_rate, NOW()
            )
            ON CONFLICT (nft_id, date) DO UPDATE SET
                daily_profit = EXCLUDED.daily_profit,
                yield_rate = EXCLUDED.yield_rate,
                created_at = NOW();
        END IF;
    END LOOP;

    -- ⭐ STEP 2: ユーザーごとの集計と紹介報酬（運用開始済みユーザーのみ）
    -- 🔧 修正: total_nft_count * 1000 で再計算せず、nft_daily_profit から集計する
    FOR v_user_record IN
        SELECT
            ac.user_id,
            ac.available_usdt,
            ac.cum_usdt
        FROM affiliate_cycle ac
        INNER JOIN users u ON ac.user_id = u.user_id
        WHERE ac.total_nft_count > 0
          AND u.operation_start_date IS NOT NULL
          AND u.operation_start_date <= p_date
    LOOP
        v_user_count := v_user_count + 1;

        -- 🔧 修正: STEP1で計算済みの個人利益を nft_daily_profit から取得
        SELECT COALESCE(SUM(daily_profit), 0)
        INTO v_user_profit
        FROM nft_daily_profit
        WHERE user_id = v_user_record.user_id
          AND date = p_date;

        -- 個人利益 → available_usdt
        v_new_available_usdt := v_user_record.available_usdt + v_user_profit;

        -- 紹介報酬を計算して cum_usdt に追加
        DECLARE
            v_referral_reward NUMERIC := 0;
        BEGIN
            SELECT COALESCE(SUM(referral_amount), 0)
            INTO v_referral_reward
            FROM calculate_daily_referral_rewards(v_user_record.user_id, p_date);

            IF v_referral_reward > 0 THEN
                v_referral_count := v_referral_count + 1;
            END IF;

            v_new_cum_usdt := v_user_record.cum_usdt + v_referral_reward;
        END;

        IF NOT p_is_test_mode THEN
            UPDATE affiliate_cycle
            SET
                available_usdt = v_new_available_usdt,
                cum_usdt = v_new_cum_usdt,
                last_updated = NOW()
            WHERE user_id = v_user_record.user_id;
        END IF;
    END LOOP;

    -- ⭐ STEP 3: NFT自動付与処理
    FOR v_user_record IN
        SELECT user_id, cum_usdt, total_nft_count, auto_nft_count, cycle_number
        FROM affiliate_cycle
        WHERE cum_usdt >= 2200
    LOOP
        v_auto_purchases := v_auto_purchases + 1;
        v_auto_nft_count := FLOOR(v_user_record.cum_usdt / 2200);
        v_current_cycle_number := COALESCE(v_user_record.cycle_number, 0) + 1;

        IF NOT p_is_test_mode THEN
            SELECT COALESCE(MAX(nft_sequence), 0) + 1
            INTO v_next_nft_sequence
            FROM nft_master
            WHERE user_id = v_user_record.user_id;

            FOR i IN 1..v_auto_nft_count LOOP
                INSERT INTO nft_master (
                    user_id, nft_sequence, nft_type, nft_value,
                    acquired_date, created_at, updated_at
                )
                VALUES (
                    v_user_record.user_id, v_next_nft_sequence + i - 1,
                    'auto', 1000.00, p_date, NOW(), NOW()
                );
            END LOOP;

            INSERT INTO purchases (
                user_id, nft_quantity, amount_usd, payment_status,
                admin_approved, is_auto_purchase, admin_approved_at, admin_approved_by,
                cycle_number_at_purchase
            )
            VALUES (
                v_user_record.user_id, v_auto_nft_count, v_auto_nft_count * 1100,
                'completed', true, true, NOW(), 'SYSTEM_AUTO',
                v_current_cycle_number
            );

            UPDATE affiliate_cycle
            SET
                total_nft_count = total_nft_count + v_auto_nft_count,
                auto_nft_count = auto_nft_count + v_auto_nft_count,
                cum_usdt = v_user_record.cum_usdt - (v_auto_nft_count * 2200),
                available_usdt = available_usdt + (v_auto_nft_count * 1100),
                phase = CASE
                    WHEN (v_user_record.cum_usdt - (v_auto_nft_count * 2200)) >= 1100 THEN 'HOLD'
                    ELSE 'USDT'
                END,
                cycle_number = cycle_number + v_auto_nft_count,
                last_updated = NOW()
            WHERE user_id = v_user_record.user_id;
        END IF;

        v_cycle_updates := v_cycle_updates + 1;
    END LOOP;

    -- ⭐ STEP 4: 月末なら自動的に出金処理を実行
    IF v_is_month_end AND NOT p_is_test_mode THEN
        BEGIN
            RAISE NOTICE '=== 月末検知: 自動的に出金処理を実行します ===';

            SELECT processed_count
            INTO v_monthly_withdrawal_count
            FROM process_monthly_withdrawals(DATE_TRUNC('month', p_date)::DATE);

            RAISE NOTICE '=== 月末出金処理完了: %件 ===', v_monthly_withdrawal_count;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING '月末出金処理でエラーが発生しましたが、日利処理は継続します: %', SQLERRM;
            v_monthly_withdrawal_count := -1;
        END;
    END IF;

    -- 結果を返す（8列）
    RETURN QUERY SELECT
        CASE WHEN p_is_test_mode THEN 'TEST_SUCCESS' ELSE 'SUCCESS' END::TEXT,
        v_user_count::INTEGER,
        v_total_user_profit::NUMERIC,
        v_total_company_profit::NUMERIC,
        v_cycle_updates::INTEGER,
        v_auto_purchases::INTEGER,
        v_referral_count::INTEGER,
        v_monthly_withdrawal_count::INTEGER,
        FORMAT('%s完了: %s名処理, %s人紹介報酬更新, %s回サイクル更新, %s回自動NFT購入%s',
               CASE WHEN p_is_test_mode THEN 'テスト' ELSE '本番' END,
               v_user_count, v_referral_count, v_cycle_updates, v_auto_purchases,
               CASE
                   WHEN v_is_month_end AND NOT p_is_test_mode THEN
                       FORMAT(', %s件月末出金処理', v_monthly_withdrawal_count)
                   ELSE ''
               END)::TEXT;

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT
        'ERROR'::TEXT,
        0::INTEGER,
        0::NUMERIC,
        0::NUMERIC,
        0::INTEGER,
        0::INTEGER,
        0::INTEGER,
        0::INTEGER,
        FORMAT('エラー: %s', SQLERRM)::TEXT;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN, BOOLEAN) TO anon;
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN, BOOLEAN) TO authenticated;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '=========================================';
    RAISE NOTICE '✅ 個人配当計算のバグを修正しました';
    RAISE NOTICE '=========================================';
    RAISE NOTICE '修正内容:';
    RAISE NOTICE '  STEP2: total_nft_count × 1000 で再計算';
    RAISE NOTICE '    ↓';
    RAISE NOTICE '  STEP2: nft_daily_profit から集計';
    RAISE NOTICE '';
    RAISE NOTICE '効果:';
    RAISE NOTICE '  - 自動NFT付与時も正しい個人配当額になる';
    RAISE NOTICE '  - STEP1で計算済みのデータを再利用（整合性保証）';
    RAISE NOTICE '=========================================';
END $$;
