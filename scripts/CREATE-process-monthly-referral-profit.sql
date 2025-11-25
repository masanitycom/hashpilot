-- ========================================
-- 月次紹介報酬計算RPC関数
-- ========================================
-- 作成日: 2025-11-23
--
-- 機能: 指定月の紹介報酬を計算してmonthly_referral_profitに記録
-- 実行タイミング: 月末の日利処理後、または管理画面から手動実行
-- ========================================

CREATE OR REPLACE FUNCTION process_monthly_referral_profit(
    p_year_month TEXT,              -- 'YYYY-MM' 形式
    p_is_test_mode BOOLEAN DEFAULT FALSE
)
RETURNS TABLE(
    status TEXT,
    message TEXT,
    details JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_date DATE;
    v_end_date DATE;
    v_level1_rate NUMERIC := 0.20;
    v_level2_rate NUMERIC := 0.10;
    v_level3_rate NUMERIC := 0.05;
    v_user_record RECORD;
    v_referral_record RECORD;
    v_child_monthly_profit NUMERIC;
    v_referral_amount NUMERIC;
    v_total_referral NUMERIC := 0;
    v_referral_count INTEGER := 0;
    v_auto_nft_count INTEGER := 0;
    v_user_count INTEGER := 0;
BEGIN
    -- ========================================
    -- STEP 1: 入力検証
    -- ========================================
    IF p_year_month IS NULL OR p_year_month !~ '^\d{4}-\d{2}$' THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            '年月はYYYY-MM形式で指定してください'::TEXT,
            NULL::JSONB;
        RETURN;
    END IF;

    -- 対象月の開始日と終了日を計算
    v_start_date := (p_year_month || '-01')::DATE;
    v_end_date := (v_start_date + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

    -- 重複チェック
    IF EXISTS (
        SELECT 1 FROM monthly_referral_profit WHERE year_month = p_year_month
    ) THEN
        IF NOT p_is_test_mode THEN
            RETURN QUERY SELECT
                'ERROR'::TEXT,
                format('年月 %s の紹介報酬は既に計算済みです', p_year_month)::TEXT,
                NULL::JSONB;
            RETURN;
        ELSE
            -- テストモードの場合は既存データを削除
            DELETE FROM monthly_referral_profit WHERE year_month = p_year_month;

            -- cum_usdtから既存の紹介報酬を差し引く（ロールバック）
            UPDATE affiliate_cycle ac
            SET cum_usdt = cum_usdt - COALESCE((
                SELECT SUM(profit_amount)
                FROM monthly_referral_profit mrp
                WHERE mrp.user_id = ac.user_id
                    AND mrp.year_month = p_year_month
            ), 0);
        END IF;
    END IF;

    -- ========================================
    -- STEP 2: 紹介者がいるユーザーを取得
    -- ========================================
    FOR v_user_record IN
        SELECT DISTINCT u.user_id
        FROM users u
        WHERE u.has_approved_nft = true
            AND u.operation_start_date IS NOT NULL
            AND u.operation_start_date <= v_end_date
            AND EXISTS (
                SELECT 1 FROM users child
                WHERE child.referrer_user_id = u.user_id
            )
    LOOP
        -- ========================================
        -- Level 1: 直接紹介者
        -- ========================================
        FOR v_referral_record IN
            SELECT
                child.user_id as child_user_id,
                COALESCE(SUM(ndp.daily_profit), 0) as monthly_profit
            FROM users child
            LEFT JOIN nft_daily_profit ndp
                ON child.user_id = ndp.user_id
                AND ndp.date BETWEEN v_start_date AND v_end_date
            WHERE child.referrer_user_id = v_user_record.user_id
                AND child.has_approved_nft = true
                AND child.operation_start_date IS NOT NULL
                AND child.operation_start_date <= v_end_date
            GROUP BY child.user_id
            HAVING COALESCE(SUM(ndp.daily_profit), 0) > 0  -- プラス利益のみ
        LOOP
            v_child_monthly_profit := v_referral_record.monthly_profit;
            v_referral_amount := v_child_monthly_profit * v_level1_rate;

            INSERT INTO monthly_referral_profit (
                user_id,
                year_month,
                referral_level,
                child_user_id,
                profit_amount,
                calculation_date
            ) VALUES (
                v_user_record.user_id,
                p_year_month,
                1,
                v_referral_record.child_user_id,
                v_referral_amount,
                CURRENT_DATE
            );

            -- affiliate_cycleに加算
            UPDATE affiliate_cycle
            SET
                cum_usdt = cum_usdt + v_referral_amount,
                updated_at = NOW()
            WHERE user_id = v_user_record.user_id;

            v_total_referral := v_total_referral + v_referral_amount;
            v_referral_count := v_referral_count + 1;
        END LOOP;

        -- ========================================
        -- Level 2: 間接紹介者
        -- ========================================
        FOR v_referral_record IN
            SELECT
                child.user_id as child_user_id,
                COALESCE(SUM(ndp.daily_profit), 0) as monthly_profit
            FROM users level1
            JOIN users child ON child.referrer_user_id = level1.user_id
            LEFT JOIN nft_daily_profit ndp
                ON child.user_id = ndp.user_id
                AND ndp.date BETWEEN v_start_date AND v_end_date
            WHERE level1.referrer_user_id = v_user_record.user_id
                AND level1.has_approved_nft = true
                AND child.has_approved_nft = true
                AND child.operation_start_date IS NOT NULL
                AND child.operation_start_date <= v_end_date
            GROUP BY child.user_id
            HAVING COALESCE(SUM(ndp.daily_profit), 0) > 0
        LOOP
            v_child_monthly_profit := v_referral_record.monthly_profit;
            v_referral_amount := v_child_monthly_profit * v_level2_rate;

            INSERT INTO monthly_referral_profit (
                user_id,
                year_month,
                referral_level,
                child_user_id,
                profit_amount,
                calculation_date
            ) VALUES (
                v_user_record.user_id,
                p_year_month,
                2,
                v_referral_record.child_user_id,
                v_referral_amount,
                CURRENT_DATE
            );

            UPDATE affiliate_cycle
            SET
                cum_usdt = cum_usdt + v_referral_amount,
                updated_at = NOW()
            WHERE user_id = v_user_record.user_id;

            v_total_referral := v_total_referral + v_referral_amount;
            v_referral_count := v_referral_count + 1;
        END LOOP;

        -- ========================================
        -- Level 3: 間接紹介者
        -- ========================================
        FOR v_referral_record IN
            SELECT
                child.user_id as child_user_id,
                COALESCE(SUM(ndp.daily_profit), 0) as monthly_profit
            FROM users level1
            JOIN users level2 ON level2.referrer_user_id = level1.user_id
            JOIN users child ON child.referrer_user_id = level2.user_id
            LEFT JOIN nft_daily_profit ndp
                ON child.user_id = ndp.user_id
                AND ndp.date BETWEEN v_start_date AND v_end_date
            WHERE level1.referrer_user_id = v_user_record.user_id
                AND level1.has_approved_nft = true
                AND level2.has_approved_nft = true
                AND child.has_approved_nft = true
                AND child.operation_start_date IS NOT NULL
                AND child.operation_start_date <= v_end_date
            GROUP BY child.user_id
            HAVING COALESCE(SUM(ndp.daily_profit), 0) > 0
        LOOP
            v_child_monthly_profit := v_referral_record.monthly_profit;
            v_referral_amount := v_child_monthly_profit * v_level3_rate;

            INSERT INTO monthly_referral_profit (
                user_id,
                year_month,
                referral_level,
                child_user_id,
                profit_amount,
                calculation_date
            ) VALUES (
                v_user_record.user_id,
                p_year_month,
                3,
                v_referral_record.child_user_id,
                v_referral_amount,
                CURRENT_DATE
            );

            UPDATE affiliate_cycle
            SET
                cum_usdt = cum_usdt + v_referral_amount,
                updated_at = NOW()
            WHERE user_id = v_user_record.user_id;

            v_total_referral := v_total_referral + v_referral_amount;
            v_referral_count := v_referral_count + 1;
        END LOOP;

        v_user_count := v_user_count + 1;
    END LOOP;

    -- ========================================
    -- STEP 3: NFT自動付与（cum_usdt >= $2,200）
    -- ========================================
    FOR v_user_record IN
        SELECT
            u.user_id,
            u.id as user_uuid,
            ac.cum_usdt,
            ac.auto_nft_count
        FROM users u
        JOIN affiliate_cycle ac ON u.user_id = ac.user_id
        WHERE ac.cum_usdt >= 2200
    LOOP
        INSERT INTO nft_master (
            user_id,
            nft_type,
            acquired_date,
            buyback_date
        ) VALUES (
            v_user_record.user_id,
            'auto',
            v_end_date,  -- 月末日付
            NULL
        );

        INSERT INTO purchases (
            user_id,
            nft_type,
            usdt_amount,
            payment_tx_id,
            payment_method,
            admin_approved,
            admin_approved_at,
            cycle_number_at_purchase,
            purchase_date
        ) VALUES (
            v_user_record.user_id,
            'auto',
            1100,
            'AUTO_' || p_year_month || '_' || v_user_record.user_id,
            'cycle_reward',
            true,
            NOW(),
            v_user_record.auto_nft_count + 1,
            v_end_date
        );

        UPDATE affiliate_cycle
        SET
            cum_usdt = cum_usdt - 2200,
            available_usdt = available_usdt + 1100,
            auto_nft_count = auto_nft_count + 1,
            total_nft_count = total_nft_count + 1,
            phase = CASE WHEN (cum_usdt - 2200) >= 1100 THEN 'HOLD' ELSE 'USDT' END,
            updated_at = NOW()
        WHERE user_id = v_user_record.user_id;

        UPDATE users
        SET
            has_approved_nft = true,
            updated_at = NOW()
        WHERE user_id = v_user_record.user_id;

        v_auto_nft_count := v_auto_nft_count + 1;
    END LOOP;

    -- ========================================
    -- STEP 4: 結果を返す
    -- ========================================
    RETURN QUERY SELECT
        'SUCCESS'::TEXT,
        format('月次紹介報酬計算完了: %s', p_year_month)::TEXT,
        jsonb_build_object(
            'year_month', p_year_month,
            'period', jsonb_build_object(
                'start_date', v_start_date,
                'end_date', v_end_date
            ),
            'distribution', jsonb_build_object(
                'user_count', v_user_count,
                'referral_count', v_referral_count,
                'total_referral', v_total_referral,
                'auto_nft_count', v_auto_nft_count
            )
        );

EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT
            'ERROR'::TEXT,
            format('エラー: %s', SQLERRM)::TEXT,
            jsonb_build_object('error_detail', SQLERRM);
END;
$$;

-- ============================================
-- コメント
-- ============================================

COMMENT ON FUNCTION process_monthly_referral_profit IS '月次紹介報酬を計算してmonthly_referral_profitに記録（月末実行）';

-- 完了メッセージ
DO $$
BEGIN
    RAISE NOTICE '============================================';
    RAISE NOTICE '✅ 月次紹介報酬計算RPC関数を作成しました';
    RAISE NOTICE '============================================';
    RAISE NOTICE '📋 関数名: process_monthly_referral_profit';
    RAISE NOTICE '';
    RAISE NOTICE '📊 パラメータ:';
    RAISE NOTICE '   - p_year_month: YYYY-MM形式（例: ''2025-11''）';
    RAISE NOTICE '   - p_is_test_mode: テストモード（既存データ削除）';
    RAISE NOTICE '';
    RAISE NOTICE '📊 処理内容:';
    RAISE NOTICE '   1. 指定月の個人利益を集計';
    RAISE NOTICE '   2. 紹介報酬を計算（Level 1: 20%, 2: 10%, 3: 5%）';
    RAISE NOTICE '   3. monthly_referral_profitに記録';
    RAISE NOTICE '   4. affiliate_cycle.cum_usdtに加算';
    RAISE NOTICE '   5. NFT自動付与（cum_usdt >= $2,200）';
    RAISE NOTICE '';
    RAISE NOTICE '✅ 使用例:';
    RAISE NOTICE '   SELECT * FROM process_monthly_referral_profit(''2025-11'', FALSE);';
    RAISE NOTICE '============================================';
END $$;
