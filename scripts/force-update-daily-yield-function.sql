-- 日利計算関数を強制的に更新
-- 既存の関数を完全に削除してから再作成

SELECT '=== STEP 1: 既存関数の完全削除 ===' as section;

-- 全ての既存バージョンを削除（CASCADE付き）
DROP FUNCTION IF EXISTS process_daily_yield_with_cycles(date,numeric,numeric,boolean,boolean) CASCADE;
DROP FUNCTION IF EXISTS process_daily_yield_with_cycles(date,numeric,numeric,boolean) CASCADE;
DROP FUNCTION IF EXISTS process_daily_yield_with_cycles(date,numeric,numeric) CASCADE;
DROP FUNCTION IF EXISTS process_daily_yield_with_cycles(date,numeric) CASCADE;
DROP FUNCTION IF EXISTS process_daily_yield_with_cycles CASCADE;

SELECT '削除完了' as status;

SELECT '=== STEP 2: 新しい関数を作成 ===' as section;

CREATE FUNCTION process_daily_yield_with_cycles(
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
    v_user_rate NUMERIC;
    v_after_margin NUMERIC;
    v_user_record RECORD;
    v_nft_record RECORD;
    v_user_profit NUMERIC;
    v_nft_profit NUMERIC;
    v_company_profit NUMERIC;
    v_base_amount NUMERIC;
    v_auto_nft_count INTEGER := 0;
    v_next_nft_sequence INTEGER;
    v_referral_reward NUMERIC;
    v_month_start DATE;
    v_month_end DATE;
BEGIN
    -- 利率のバリデーション
    IF NOT p_skip_validation THEN
        IF p_yield_rate < 0 OR p_yield_rate > 0.1 THEN
            RAISE EXCEPTION 'Invalid yield rate: % (must be between 0 and 0.1)', p_yield_rate;
        END IF;
    END IF;

    -- 今月の範囲を計算
    v_month_start := DATE_TRUNC('month', p_date)::DATE;
    v_month_end := (DATE_TRUNC('month', p_date) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

    -- 利率計算
    v_after_margin := p_yield_rate * (1 - p_margin_rate / 100);
    v_user_rate := v_after_margin * 0.6;

    -- テストモードでない場合のみdaily_yield_logに記録
    IF NOT p_is_test_mode THEN
        INSERT INTO daily_yield_log (
            date, yield_rate, margin_rate, user_rate, is_month_end, created_at
        )
        VALUES (
            p_date, p_yield_rate, p_margin_rate, v_user_rate, false, NOW()
        )
        ON CONFLICT (date) DO UPDATE SET
            yield_rate = EXCLUDED.yield_rate,
            margin_rate = EXCLUDED.margin_rate,
            user_rate = EXCLUDED.user_rate,
            created_at = NOW();
    END IF;

    -- STEP 1: 各ユーザーの個人利益を処理（available_usdtに直接加算）
    FOR v_user_record IN
        SELECT
            user_id,
            phase,
            total_nft_count,
            cum_usdt,
            available_usdt,
            auto_nft_count,
            manual_nft_count
        FROM affiliate_cycle
        WHERE total_nft_count > 0
    LOOP
        -- 基準金額（NFT数 × 1100）
        v_base_amount := v_user_record.total_nft_count * 1100;

        -- ユーザー利益計算（全NFTの合計）
        v_user_profit := v_base_amount * v_user_rate;

        -- 会社利益計算
        v_company_profit := v_base_amount * p_margin_rate / 100 + v_base_amount * v_after_margin * 0.1;

        -- ⭐ 個人利益はavailable_usdtに直接加算（サイクルには含めない）
        IF NOT p_is_test_mode THEN
            UPDATE affiliate_cycle
            SET
                available_usdt = available_usdt + v_user_profit,
                last_updated = NOW()
            WHERE user_id = v_user_record.user_id;

            -- NFTごとの日次利益を記録
            v_nft_profit := v_user_profit / v_user_record.total_nft_count;

            FOR v_nft_record IN
                SELECT id, nft_sequence, nft_type
                FROM nft_master
                WHERE user_id = v_user_record.user_id
                  AND buyback_date IS NULL
                ORDER BY nft_sequence
            LOOP
                INSERT INTO nft_daily_profit (
                    nft_id, user_id, date, daily_profit, yield_rate, user_rate,
                    base_amount, phase, created_at
                )
                VALUES (
                    v_nft_record.id, v_user_record.user_id, p_date, v_nft_profit,
                    p_yield_rate, v_user_rate, 1100,
                    v_user_record.phase, NOW()
                )
                ON CONFLICT (nft_id, date) DO UPDATE SET
                    daily_profit = EXCLUDED.daily_profit,
                    yield_rate = EXCLUDED.yield_rate,
                    user_rate = EXCLUDED.user_rate,
                    base_amount = EXCLUDED.base_amount,
                    phase = EXCLUDED.phase,
                    created_at = NOW();
            END LOOP;

            -- user_daily_profitテーブルに集計を記録
            INSERT INTO user_daily_profit (
                user_id, date, daily_profit, yield_rate, user_rate, base_amount, phase, created_at
            )
            VALUES (
                v_user_record.user_id, p_date, v_user_profit, p_yield_rate, v_user_rate,
                v_base_amount, v_user_record.phase, NOW()
            )
            ON CONFLICT (user_id, date) DO UPDATE SET
                daily_profit = EXCLUDED.daily_profit,
                yield_rate = EXCLUDED.yield_rate,
                user_rate = EXCLUDED.user_rate,
                base_amount = EXCLUDED.base_amount,
                phase = EXCLUDED.phase,
                created_at = NOW();
        END IF;

        v_user_count := v_user_count + 1;
        v_total_user_profit := v_total_user_profit + v_user_profit;
        v_total_company_profit := v_total_company_profit + v_company_profit;
    END LOOP;

    -- ⭐ STEP 2: 紹介報酬を計算してcum_usdtに反映
    IF NOT p_is_test_mode THEN
        FOR v_user_record IN
            SELECT DISTINCT u.user_id
            FROM users u
            WHERE EXISTS (
                SELECT 1 FROM users ref
                WHERE ref.referrer_user_id = u.user_id
                  AND ref.has_approved_nft = true
            )
        LOOP
            -- 今月の紹介報酬を計算
            SELECT COALESCE(SUM(udp.daily_profit) * 0.20, 0)
            INTO v_referral_reward
            FROM user_daily_profit udp
            JOIN users u ON udp.user_id = u.user_id
            WHERE u.referrer_user_id = v_user_record.user_id
              AND u.has_approved_nft = true
              AND udp.date >= v_month_start
              AND udp.date <= v_month_end;

            -- cum_usdtを更新
            UPDATE affiliate_cycle
            SET
                cum_usdt = v_referral_reward,
                last_updated = NOW()
            WHERE user_id = v_user_record.user_id;

            v_referral_count := v_referral_count + 1;
        END LOOP;
    END IF;

    -- ⭐ STEP 3: NFT自動付与処理（cum_usdt >= 2200のユーザー）
    FOR v_user_record IN
        SELECT
            user_id,
            cum_usdt,
            total_nft_count,
            auto_nft_count
        FROM affiliate_cycle
        WHERE cum_usdt >= 2200
    LOOP
        v_auto_purchases := v_auto_purchases + 1;
        v_auto_nft_count := FLOOR(v_user_record.cum_usdt / 2200);

        IF NOT p_is_test_mode THEN
            -- 次のNFTシーケンス番号を取得
            SELECT COALESCE(MAX(nft_sequence), 0) + 1
            INTO v_next_nft_sequence
            FROM nft_master
            WHERE user_id = v_user_record.user_id;

            -- NFTレコードを作成
            FOR i IN 1..v_auto_nft_count LOOP
                INSERT INTO nft_master (
                    user_id, nft_sequence, nft_type, nft_value,
                    acquired_date, created_at, updated_at
                )
                VALUES (
                    v_user_record.user_id, v_next_nft_sequence + i - 1,
                    'auto', 1100.00, p_date, NOW(), NOW()
                );
            END LOOP;

            -- purchasesテーブルに記録
            INSERT INTO purchases (
                user_id, nft_quantity, amount_usd, payment_status,
                admin_approved, is_auto_purchase, admin_approved_at, admin_approved_by
            )
            VALUES (
                v_user_record.user_id, v_auto_nft_count, v_auto_nft_count * 1100,
                'completed', true, true, NOW(), 'SYSTEM_AUTO'
            );

            -- affiliate_cycleテーブルを更新
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

    -- 結果を返す
    RETURN QUERY SELECT
        CASE WHEN p_is_test_mode THEN 'TEST_SUCCESS' ELSE 'SUCCESS' END::TEXT,
        v_user_count::INTEGER,
        v_total_user_profit::NUMERIC,
        v_total_company_profit::NUMERIC,
        v_cycle_updates::INTEGER,
        v_auto_purchases::INTEGER,
        v_referral_count::INTEGER,
        FORMAT('%s完了: %s名処理, %s人紹介報酬更新, %s回サイクル更新, %s回自動NFT購入',
               CASE WHEN p_is_test_mode THEN 'テスト' ELSE '本番' END,
               v_user_count, v_referral_count, v_cycle_updates, v_auto_purchases)::TEXT;

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT
        'ERROR'::TEXT,
        0::INTEGER,
        0::NUMERIC,
        0::NUMERIC,
        0::INTEGER,
        0::INTEGER,
        0::INTEGER,
        FORMAT('エラー: %s', SQLERRM)::TEXT;
END;
$$;

SELECT '関数作成完了' as status;

SELECT '=== STEP 3: 権限付与 ===' as section;

GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN, BOOLEAN) TO anon;
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN, BOOLEAN) TO authenticated;

SELECT '権限付与完了' as status;

SELECT '=== STEP 4: 確認テスト ===' as section;

-- 新しい関数が7列返すか確認
SELECT * FROM process_daily_yield_with_cycles(
    CURRENT_DATE,
    0.01,
    30.0,
    true,
    false
);

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE '✅ 関数更新完了';
    RAISE NOTICE '===========================================';
    RAISE NOTICE '変更点:';
    RAISE NOTICE '  1. 個人利益 → available_usdtのみ';
    RAISE NOTICE '  2. 紹介報酬 → cum_usdtに反映';
    RAISE NOTICE '  3. cum_usdt >= 2200 で自動NFT付与';
    RAISE NOTICE '';
    RAISE NOTICE '確認:';
    RAISE NOTICE '  - 上記で7列返っていればOK';
    RAISE NOTICE '  - referral_rewards_processed列があるはず';
    RAISE NOTICE '===========================================';
END $$;
