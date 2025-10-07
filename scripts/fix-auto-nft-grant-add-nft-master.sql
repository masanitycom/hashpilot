-- 自動NFT付与機能の修正
-- nft_masterテーブルにも実際のNFTレコードを作成する
-- 作成日: 2025年10月7日

-- 既存の関数を削除
DROP FUNCTION IF EXISTS process_daily_yield_with_cycles(date,numeric,numeric,boolean,boolean);
DROP FUNCTION IF EXISTS process_daily_yield_with_cycles(date,numeric,numeric,boolean);
DROP FUNCTION IF EXISTS process_daily_yield_with_cycles(date,numeric,numeric);
DROP FUNCTION IF EXISTS process_daily_yield_with_cycles(date,numeric);

-- 新しい関数を作成
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
    v_user_rate NUMERIC;
    v_after_margin NUMERIC;
    v_user_record RECORD;
    v_nft_record RECORD;
    v_user_profit NUMERIC;
    v_nft_profit NUMERIC;
    v_company_profit NUMERIC;
    v_base_amount NUMERIC;
    v_new_cum_usdt NUMERIC;
    v_auto_nft_count INTEGER := 0;
    v_next_nft_sequence INTEGER;
BEGIN
    -- 利率のバリデーション
    IF NOT p_skip_validation THEN
        IF p_yield_rate < 0 OR p_yield_rate > 0.1 THEN
            RAISE EXCEPTION 'Invalid yield rate: % (must be between 0 and 0.1)', p_yield_rate;
        END IF;
    END IF;

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

    -- 各ユーザーの処理
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

        -- サイクル処理
        v_new_cum_usdt := v_user_record.cum_usdt + v_user_profit;

        -- フェーズ判定とcum_usdt処理
        IF v_new_cum_usdt >= 2200 THEN
            -- 🎯 自動NFT購入処理
            v_auto_purchases := v_auto_purchases + 1;
            v_auto_nft_count := FLOOR(v_new_cum_usdt / 2200);

            IF NOT p_is_test_mode THEN
                -- 次のNFTシーケンス番号を取得
                SELECT COALESCE(MAX(nft_sequence), 0) + 1
                INTO v_next_nft_sequence
                FROM nft_master
                WHERE user_id = v_user_record.user_id;

                -- 📝 nft_masterテーブルに実際のNFTレコードを作成
                FOR i IN 1..v_auto_nft_count LOOP
                    INSERT INTO nft_master (
                        user_id,
                        nft_sequence,
                        nft_type,
                        nft_value,
                        acquired_date,
                        created_at,
                        updated_at
                    )
                    VALUES (
                        v_user_record.user_id,
                        v_next_nft_sequence + i - 1,
                        'auto',
                        1100.00,
                        p_date,
                        NOW(),
                        NOW()
                    );
                END LOOP;

                -- 📝 purchasesテーブルに自動購入レコードを作成
                INSERT INTO purchases (
                    user_id,
                    nft_quantity,
                    amount_usd,
                    payment_status,
                    admin_approved,
                    is_auto_purchase,
                    admin_approved_at,
                    admin_approved_by
                )
                VALUES (
                    v_user_record.user_id,
                    v_auto_nft_count,
                    v_auto_nft_count * 1100,
                    'completed',
                    true,
                    true,
                    NOW(),
                    'SYSTEM_AUTO'
                );

                -- affiliate_cycleテーブルを更新
                UPDATE affiliate_cycle
                SET
                    total_nft_count = total_nft_count + v_auto_nft_count,
                    auto_nft_count = auto_nft_count + v_auto_nft_count,
                    cum_usdt = v_new_cum_usdt - (v_auto_nft_count * 2200),
                    available_usdt = available_usdt + (v_auto_nft_count * 1100),
                    phase = 'USDT',
                    cycle_number = cycle_number + v_auto_nft_count,
                    last_updated = NOW()
                WHERE user_id = v_user_record.user_id;
            END IF;

            v_cycle_updates := v_cycle_updates + 1;

        ELSIF v_new_cum_usdt >= 1100 THEN
            -- HOLDフェーズ
            IF NOT p_is_test_mode THEN
                UPDATE affiliate_cycle
                SET
                    cum_usdt = v_new_cum_usdt,
                    phase = 'HOLD',
                    last_updated = NOW()
                WHERE user_id = v_user_record.user_id;
            END IF;

            v_cycle_updates := v_cycle_updates + 1;

        ELSE
            -- USDTフェーズ（即時受取可能）
            IF NOT p_is_test_mode THEN
                UPDATE affiliate_cycle
                SET
                    cum_usdt = v_new_cum_usdt,
                    available_usdt = available_usdt + v_user_profit,
                    phase = 'USDT',
                    last_updated = NOW()
                WHERE user_id = v_user_record.user_id;
            END IF;

            v_cycle_updates := v_cycle_updates + 1;
        END IF;

        -- 📊 NFTごとの日次利益を記録（テストモードでない場合のみ）
        IF NOT p_is_test_mode THEN
            -- NFT1つあたりの利益
            v_nft_profit := v_user_profit / v_user_record.total_nft_count;

            -- 各NFTの利益を記録
            FOR v_nft_record IN
                SELECT id, nft_sequence, nft_type
                FROM nft_master
                WHERE user_id = v_user_record.user_id
                  AND buyback_date IS NULL
                ORDER BY nft_sequence
            LOOP
                INSERT INTO nft_daily_profit (
                    nft_id,
                    user_id,
                    date,
                    daily_profit,
                    yield_rate,
                    user_rate,
                    base_amount,
                    phase,
                    created_at
                )
                VALUES (
                    v_nft_record.id,
                    v_user_record.user_id,
                    p_date,
                    v_nft_profit,
                    p_yield_rate,
                    v_user_rate,
                    1100,
                    CASE WHEN v_new_cum_usdt >= 1100 THEN 'HOLD' ELSE 'USDT' END,
                    NOW()
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
                v_user_record.user_id, p_date, v_user_profit, p_yield_rate, v_user_rate, v_base_amount,
                CASE WHEN v_new_cum_usdt >= 1100 THEN 'HOLD' ELSE 'USDT' END, NOW()
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

    -- 結果を返す
    RETURN QUERY SELECT
        CASE WHEN p_is_test_mode THEN 'TEST_SUCCESS' ELSE 'SUCCESS' END::TEXT,
        v_user_count::INTEGER,
        v_total_user_profit::NUMERIC,
        v_total_company_profit::NUMERIC,
        v_cycle_updates::INTEGER,
        v_auto_purchases::INTEGER,
        FORMAT('%s完了: %s名処理, %s回サイクル更新, %s回自動NFT購入',
               CASE WHEN p_is_test_mode THEN 'テスト' ELSE '本番' END,
               v_user_count, v_cycle_updates, v_auto_purchases)::TEXT;

EXCEPTION WHEN OTHERS THEN
    RETURN QUERY SELECT
        'ERROR'::TEXT,
        0::INTEGER,
        0::NUMERIC,
        0::NUMERIC,
        0::INTEGER,
        0::INTEGER,
        FORMAT('エラー: %s', SQLERRM)::TEXT;
END;
$$;

-- 実行権限付与
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN, BOOLEAN) TO anon;
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN, BOOLEAN) TO authenticated;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Auto NFT grant function updated successfully';
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Changes:';
    RAISE NOTICE '  - Creates actual NFT records in nft_master';
    RAISE NOTICE '  - Creates auto purchase records in purchases';
    RAISE NOTICE '  - Records daily profit per NFT';
    RAISE NOTICE '  - Supports multiple NFT grants at once';
    RAISE NOTICE '';
    RAISE NOTICE 'Test method:';
    RAISE NOTICE '  1. Set cum_usdt to 1080';
    RAISE NOTICE '  2. Run daily yield calculation with 5 percent rate';
    RAISE NOTICE '  3. Verify NFT is added to nft_master';
    RAISE NOTICE '===========================================';
END $$;
