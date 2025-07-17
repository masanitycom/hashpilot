-- ========================================
-- 緊急修正：利益$0問題の完全解決
-- 運用開始日条件・LIMIT削除・正しい金額計算
-- ========================================

-- 既存関数を削除
DROP FUNCTION IF EXISTS process_daily_yield_with_cycles(date, numeric, numeric, boolean, boolean);

-- 修正版関数を作成
CREATE OR REPLACE FUNCTION process_daily_yield_with_cycles(
    p_date DATE,
    p_yield_rate NUMERIC,
    p_margin_rate NUMERIC,
    p_is_test_mode BOOLEAN DEFAULT true,
    p_is_month_end BOOLEAN DEFAULT false
)
RETURNS TABLE (
    processed_count INTEGER,
    total_profit NUMERIC,
    total_referral_profit NUMERIC,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_record RECORD;
    v_user_rate NUMERIC;
    v_affiliate_rate NUMERIC;
    v_pool_rate NUMERIC;
    v_processed_count INTEGER := 0;
    v_total_profit NUMERIC := 0;
    v_total_referral_profit NUMERIC := 0;
    v_daily_profit NUMERIC;
    v_referral_profit NUMERIC;
    v_base_amount NUMERIC;
    v_new_cum_usdt NUMERIC;
    v_new_available_usdt NUMERIC;
    v_auto_nft_count INTEGER;
    v_phase TEXT;
    v_next_action TEXT;
    v_operation_start_date DATE;
BEGIN
    -- パラメータ検証
    IF p_yield_rate <= 0 OR p_yield_rate > 0.1 THEN
        RAISE EXCEPTION 'Invalid yield rate: % (must be between 0 and 0.1)', p_yield_rate;
    END IF;

    IF p_margin_rate < 0 OR p_margin_rate > 100 THEN
        RAISE EXCEPTION 'Invalid margin rate: % (must be between 0 and 100)', p_margin_rate;
    END IF;

    -- レート計算
    v_user_rate := p_yield_rate * (1 - p_margin_rate / 100) * 0.6;  -- ユーザー取り分60%
    v_affiliate_rate := p_yield_rate * (1 - p_margin_rate / 100) * 0.3;  -- アフィリエイト30%
    v_pool_rate := p_yield_rate * (1 - p_margin_rate / 100) * 0.1;  -- プール10%

    -- daily_yield_logに記録
    INSERT INTO daily_yield_log (date, yield_rate, margin_rate, user_rate, is_month_end)
    VALUES (p_date, p_yield_rate, p_margin_rate, v_user_rate, p_is_month_end)
    ON CONFLICT (date) DO UPDATE SET
        yield_rate = EXCLUDED.yield_rate,
        margin_rate = EXCLUDED.margin_rate,
        user_rate = EXCLUDED.user_rate,
        is_month_end = EXCLUDED.is_month_end,
        created_at = NOW();

    -- 🔧 修正：運用開始済みユーザー全員を処理（LIMIT削除）
    FOR v_user_record IN
        SELECT 
            u.user_id,
            u.total_purchases,
            ac.cum_usdt,
            ac.available_usdt,
            ac.total_nft_count,
            ac.auto_nft_count,
            ac.manual_nft_count,
            ac.phase,
            ac.next_action,
            ac.cycle_number,
            MIN(p.admin_approved_at)::date as first_approved_date
        FROM users u
        INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
        INNER JOIN purchases p ON u.user_id = p.user_id
        WHERE u.has_approved_nft = true
        AND p.admin_approved = true
        AND p.admin_approved_at IS NOT NULL
        -- 🔧 修正：運用開始日条件を追加（NFT承認+15日）
        AND (p.admin_approved_at + INTERVAL '15 days')::date <= p_date
        GROUP BY u.user_id, u.total_purchases, ac.cum_usdt, ac.available_usdt, 
                 ac.total_nft_count, ac.auto_nft_count, ac.manual_nft_count, 
                 ac.phase, ac.next_action, ac.cycle_number
    LOOP
        -- 🔧 修正：正しい運用額で計算（1000ドル/NFT、手数料100ドルを除く）
        v_base_amount := v_user_record.total_nft_count * 1000;
        v_daily_profit := v_base_amount * v_user_rate;
        v_referral_profit := v_base_amount * v_affiliate_rate;

        -- 累積USDTと利用可能USDTを更新
        v_new_cum_usdt := v_user_record.cum_usdt + v_daily_profit;
        v_new_available_usdt := v_user_record.available_usdt + v_daily_profit;

        -- サイクル処理
        v_auto_nft_count := 0;
        v_next_action := v_user_record.next_action;

        -- 交互サイクル処理（1100ドル到達時）
        WHILE v_new_cum_usdt >= 1100 LOOP
            IF v_next_action = 'usdt' THEN
                -- USDT受取フェーズ
                v_new_cum_usdt := v_new_cum_usdt - 1100;
                v_new_available_usdt := v_new_available_usdt + 1100;
                v_next_action := 'nft';
            ELSE
                -- NFT購入フェーズ
                v_new_cum_usdt := v_new_cum_usdt - 1100;
                v_auto_nft_count := v_auto_nft_count + 1;
                v_next_action := 'usdt';
            END IF;
        END LOOP;

        -- フェーズ判定
        IF v_new_cum_usdt < 1100 AND v_next_action = 'usdt' THEN
            v_phase := 'USDT';
        ELSE
            v_phase := 'HOLD';
        END IF;

        -- affiliate_cycleテーブル更新
        UPDATE affiliate_cycle
        SET 
            cum_usdt = v_new_cum_usdt,
            available_usdt = v_new_available_usdt,
            phase = v_phase,
            next_action = v_next_action,
            auto_nft_count = auto_nft_count + v_auto_nft_count,
            total_nft_count = total_nft_count + v_auto_nft_count,
            updated_at = NOW()
        WHERE user_id = v_user_record.user_id;

        -- 🔧 修正：UPSERTで重複エラー回避
        INSERT INTO user_daily_profit (
            user_id, date, daily_profit, yield_rate, user_rate, base_amount, phase, created_at
        )
        VALUES (
            v_user_record.user_id, p_date, v_daily_profit, p_yield_rate, v_user_rate, v_base_amount, v_phase, NOW()
        )
        ON CONFLICT (user_id, date) DO UPDATE SET
            daily_profit = EXCLUDED.daily_profit,
            yield_rate = EXCLUDED.yield_rate,
            user_rate = EXCLUDED.user_rate,
            base_amount = EXCLUDED.base_amount,
            phase = EXCLUDED.phase,
            created_at = NOW();

        -- 自動NFT購入記録
        IF v_auto_nft_count > 0 THEN
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

            UPDATE users
            SET total_purchases = total_purchases + (v_auto_nft_count * 1100)
            WHERE user_id = v_user_record.user_id;
        END IF;

        v_processed_count := v_processed_count + 1;
        v_total_profit := v_total_profit + v_daily_profit;
        v_total_referral_profit := v_total_referral_profit + v_referral_profit;

        -- デバッグログ
        RAISE NOTICE 'Processed user: %, NFTs: %, Base: $%, Daily profit: $%', 
            v_user_record.user_id, v_user_record.total_nft_count, v_base_amount, v_daily_profit;
    END LOOP;

    -- 月末処理
    IF p_is_month_end THEN
        INSERT INTO monthly_statistics (
            year, month, total_users, total_profit, total_auto_purchases, created_at
        )
        SELECT
            EXTRACT(YEAR FROM p_date)::INTEGER,
            EXTRACT(MONTH FROM p_date)::INTEGER,
            COUNT(DISTINCT u.user_id),
            COALESCE(SUM(udp.daily_profit), 0),
            COUNT(DISTINCT p.id) FILTER (WHERE p.is_auto_purchase = true),
            NOW()
        FROM users u
        LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
            AND DATE_TRUNC('month', udp.date) = DATE_TRUNC('month', p_date)
        LEFT JOIN purchases p ON u.user_id = p.user_id
            AND p.is_auto_purchase = true
            AND DATE_TRUNC('month', p.created_at) = DATE_TRUNC('month', p_date)
        WHERE u.has_approved_nft = true
        ON CONFLICT (year, month) DO UPDATE SET
            total_users = EXCLUDED.total_users,
            total_profit = EXCLUDED.total_profit,
            total_auto_purchases = EXCLUDED.total_auto_purchases,
            created_at = NOW();
    END IF;

    -- 処理結果ログ
    PERFORM log_system_event(
        'SUCCESS',
        'DAILY_YIELD_PROCESS',
        NULL,
        format('日利処理完了: %s (修正版)', p_date),
        jsonb_build_object(
            'date', p_date,
            'yield_rate', p_yield_rate,
            'margin_rate', p_margin_rate,
            'user_rate', v_user_rate,
            'processed_users', v_processed_count,
            'total_profit', v_total_profit,
            'total_referral_profit', v_total_referral_profit,
            'is_test_mode', p_is_test_mode,
            'is_month_end', p_is_month_end
        )
    );

    RETURN QUERY
    SELECT 
        v_processed_count,
        v_total_profit,
        v_total_referral_profit,
        format('修正版処理完了: %s users, Total: $%s, Mode: %s',
            v_processed_count,
            v_total_profit::TEXT,
            CASE WHEN p_is_test_mode THEN 'TEST' ELSE 'PRODUCTION' END
        );

EXCEPTION
    WHEN OTHERS THEN
        PERFORM log_system_event(
            'ERROR',
            'DAILY_YIELD_PROCESS',
            NULL,
            format('日利処理エラー: %s', SQLERRM),
            jsonb_build_object(
                'date', p_date,
                'error', SQLERRM,
                'error_detail', SQLSTATE
            )
        );
        RAISE;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles TO authenticated;
GRANT EXECUTE ON FUNCTION process_daily_yield_with_cycles TO anon;

-- 🧹 運用開始前の無効データを削除
DELETE FROM user_daily_profit 
WHERE (user_id, date) IN (
    SELECT udp.user_id, udp.date
    FROM user_daily_profit udp
    INNER JOIN purchases p ON udp.user_id = p.user_id
    WHERE p.admin_approved = true
    AND p.admin_approved_at IS NOT NULL
    AND udp.date < (p.admin_approved_at + INTERVAL '15 days')::date
);

-- テスト実行確認
COMMENT ON FUNCTION process_daily_yield_with_cycles IS '修正版：運用開始日条件追加・LIMIT削除・正しい金額計算';

-- 🔍 実行後確認用クエリ
SELECT 
    '=== 処理対象ユーザー確認 ===' as info,
    u.user_id,
    u.total_purchases,
    ac.total_nft_count,
    MIN(p.admin_approved_at)::date as first_approved,
    (MIN(p.admin_approved_at) + INTERVAL '15 days')::date as operation_start,
    CASE 
        WHEN (MIN(p.admin_approved_at) + INTERVAL '15 days')::date <= CURRENT_DATE 
        THEN '✅ 運用開始済み' 
        ELSE '⏳ 運用開始待ち' 
    END as status
FROM users u
INNER JOIN affiliate_cycle ac ON u.user_id = ac.user_id
INNER JOIN purchases p ON u.user_id = p.user_id
WHERE u.has_approved_nft = true
AND p.admin_approved = true
AND p.admin_approved_at IS NOT NULL
GROUP BY u.user_id, u.total_purchases, ac.total_nft_count
ORDER BY first_approved;