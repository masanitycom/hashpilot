-- 日利計算処理を修正してNFTごとに利益を記録
-- 作成日: 2025年10月7日
--
-- このスクリプトは process_daily_yield_with_cycles 関数を更新し、
-- NFTごとの利益を nft_daily_profit テーブルに記録するようにします。

-- ============================================
-- process_daily_yield_with_cycles 関数の更新
-- NFTごとの利益記録機能を追加
-- ============================================

CREATE OR REPLACE FUNCTION process_daily_yield_with_cycles(
    p_date DATE,
    p_yield_rate NUMERIC,
    p_margin_rate NUMERIC,
    p_is_test_mode BOOLEAN DEFAULT true
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
    v_company_profit NUMERIC;
    v_base_amount NUMERIC;
    v_new_cum_usdt NUMERIC;
    v_new_available_usdt NUMERIC;
    v_nft_profit NUMERIC; -- 個別NFTの利益
    v_current_phase TEXT;
BEGIN
    -- 利率計算（マージン適用後のユーザー受取率）
    -- マイナス利益の場合のマージン処理を含む
    IF p_yield_rate >= 0 THEN
        -- プラス利益: マージン30%を引く
        v_after_margin := p_yield_rate * (1 - p_margin_rate / 100);
    ELSE
        -- マイナス利益: マージン30%を戻す（会社が補填）
        v_after_margin := p_yield_rate * (1 + p_margin_rate / 100);
    END IF;

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

        -- ユーザー利益計算（全NFT合計）
        v_user_profit := v_base_amount * v_user_rate;

        -- 会社利益計算
        v_company_profit := v_base_amount * p_margin_rate / 100 + v_base_amount * v_after_margin * 0.1;

        -- サイクル処理
        v_new_cum_usdt := v_user_record.cum_usdt + v_user_profit;

        -- フェーズ判定とcum_usdt処理
        IF v_new_cum_usdt >= 2200 THEN
            -- 自動NFT購入処理
            v_auto_purchases := v_auto_purchases + 1;
            v_current_phase := 'USDT';

            IF NOT p_is_test_mode THEN
                -- NFT購入処理
                UPDATE affiliate_cycle
                SET
                    total_nft_count = total_nft_count + 1,
                    auto_nft_count = auto_nft_count + 1,
                    cum_usdt = v_new_cum_usdt - 2200,  -- 2200引いて残りを次サイクルへ
                    available_usdt = available_usdt + 1100,  -- 1100は即時受取可能
                    phase = 'USDT',
                    cycle_number = cycle_number + 1,
                    last_updated = NOW()
                WHERE user_id = v_user_record.user_id;

                -- 新規NFTをnft_masterに追加（自動購入）
                INSERT INTO nft_master (
                    user_id,
                    nft_sequence,
                    nft_type,
                    nft_value,
                    acquired_date
                )
                VALUES (
                    v_user_record.user_id,
                    v_user_record.auto_nft_count + v_user_record.manual_nft_count + 1,
                    'auto',
                    1100,
                    p_date
                );
            END IF;

            v_cycle_updates := v_cycle_updates + 1;

        ELSIF v_new_cum_usdt >= 1100 THEN
            -- HOLDフェーズ
            v_current_phase := 'HOLD';

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
            v_current_phase := 'USDT';

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

        -- ★★★ NFTごとに利益を記録（テストモードでない場合のみ） ★★★
        IF NOT p_is_test_mode THEN
            -- 個別NFTの利益（全NFTで均等分割）
            v_nft_profit := v_user_profit / v_user_record.total_nft_count;

            -- このユーザーの全NFT（保有中のみ）をループ
            FOR v_nft_record IN
                SELECT id, nft_sequence, nft_type
                FROM nft_master
                WHERE user_id = v_user_record.user_id
                  AND buyback_date IS NULL  -- 保有中のNFTのみ
                ORDER BY nft_sequence
            LOOP
                -- NFTごとの日次利益を記録
                INSERT INTO nft_daily_profit (
                    nft_id,
                    user_id,
                    date,
                    daily_profit,
                    yield_rate,
                    user_rate,
                    base_amount,
                    phase
                )
                VALUES (
                    v_nft_record.id,
                    v_user_record.user_id,
                    p_date,
                    v_nft_profit,
                    p_yield_rate,
                    v_user_rate,
                    1100,  -- 各NFTの基準額は1100固定
                    v_current_phase
                )
                ON CONFLICT (nft_id, date) DO UPDATE SET
                    daily_profit = EXCLUDED.daily_profit,
                    yield_rate = EXCLUDED.yield_rate,
                    user_rate = EXCLUDED.user_rate,
                    base_amount = EXCLUDED.base_amount,
                    phase = EXCLUDED.phase,
                    created_at = NOW();
            END LOOP;
        END IF;

        -- user_daily_profitテーブルにも記録（既存の集計データとして維持）
        IF NOT p_is_test_mode THEN
            DELETE FROM user_daily_profit WHERE user_id = v_user_record.user_id AND date = p_date;

            INSERT INTO user_daily_profit (
                user_id, date, daily_profit, yield_rate, user_rate, base_amount, phase, created_at
            )
            VALUES (
                v_user_record.user_id,
                p_date,
                v_user_profit,
                p_yield_rate,
                v_user_rate,
                v_base_amount,
                v_current_phase,
                NOW()
            );
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
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN) TO anon;
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles(DATE, NUMERIC, NUMERIC, BOOLEAN) TO authenticated;

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '✅ 日利計算処理を更新しました';
    RAISE NOTICE '📋 変更内容:';
    RAISE NOTICE '   - NFTごとの利益を nft_daily_profit テーブルに記録';
    RAISE NOTICE '   - 自動NFT購入時に nft_master テーブルに新規NFTを追加';
    RAISE NOTICE '   - 保有中のNFTのみに利益を記録';
    RAISE NOTICE '   - マイナス利益時のマージン計算を修正（30%補填）';
END $$;
