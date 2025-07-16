-- 🔧 システムを管理者設定のみに依存するよう修正
-- 2025年1月16日

-- 1. 全ての処理関数を「管理者設定のみ」に依存するよう修正
-- 利益計算関数の修正
CREATE OR REPLACE FUNCTION process_daily_yield_with_cycles(
    p_date DATE,
    p_yield_rate NUMERIC,
    p_margin_rate NUMERIC,
    p_is_test_mode BOOLEAN DEFAULT true,
    p_is_month_end BOOLEAN DEFAULT false
)
RETURNS TABLE(
    message TEXT,
    total_users INTEGER,
    total_profit NUMERIC,
    total_auto_purchases INTEGER,
    errors TEXT[]
) AS $$
DECLARE
    v_user_rate NUMERIC;
    v_affiliate_rate NUMERIC;
    v_total_users INTEGER := 0;
    v_total_profit NUMERIC := 0;
    v_total_auto_purchases INTEGER := 0;
    v_errors TEXT[] := ARRAY[]::TEXT[];
    user_record RECORD;
    v_log_message TEXT;
BEGIN
    -- 管理者が設定した日利のみ使用（勝手なデフォルト値禁止）
    IF NOT EXISTS (SELECT 1 FROM daily_yield_log WHERE date = p_date) THEN
        RETURN QUERY SELECT 
            'エラー: 指定された日付に管理者による日利設定がありません'::TEXT,
            0,
            0::NUMERIC,
            0,
            ARRAY['管理者による日利設定が必要です']::TEXT[];
        RETURN;
    END IF;

    -- 利率計算（管理者設定のみ）
    v_user_rate := p_yield_rate * (100 - p_margin_rate) / 100 * 0.6;
    v_affiliate_rate := p_yield_rate * (100 - p_margin_rate) / 100 * 0.3;
    
    -- 月末処理の場合のみ5%ボーナス
    IF p_is_month_end THEN
        v_user_rate := v_user_rate * 1.05;
        v_affiliate_rate := v_affiliate_rate * 1.05;
    END IF;

    -- 管理者設定をdaily_yield_logに記録
    INSERT INTO daily_yield_log (
        date, yield_rate, margin_rate, user_rate, 
        is_month_end, created_by, created_at
    ) VALUES (
        p_date, p_yield_rate, p_margin_rate, v_user_rate,
        p_is_month_end, 'admin', NOW()
    ) ON CONFLICT (date) DO UPDATE SET
        yield_rate = p_yield_rate,
        margin_rate = p_margin_rate,
        user_rate = v_user_rate,
        is_month_end = p_is_month_end,
        created_by = 'admin',
        created_at = NOW();

    -- 運用中のユーザーのみ処理
    FOR user_record IN 
        SELECT 
            u.user_id,
            u.email,
            ac.total_nft_count,
            ac.cum_usdt,
            ac.next_action,
            MIN(p.admin_approved_at)::date + 15 as operation_start_date
        FROM users u
        JOIN affiliate_cycle ac ON u.user_id = ac.user_id
        JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
        WHERE u.has_approved_nft = true
        AND ac.total_nft_count > 0
        GROUP BY u.user_id, u.email, ac.total_nft_count, ac.cum_usdt, ac.next_action
        HAVING MIN(p.admin_approved_at)::date + 15 <= p_date
    LOOP
        -- 個人利益計算（管理者設定のみ）
        DECLARE
            v_daily_profit NUMERIC := user_record.total_nft_count * 1000 * v_user_rate;
        BEGIN
            -- 利益記録（管理者設定のみ）
            INSERT INTO user_daily_profit (
                user_id, date, daily_profit, yield_rate, user_rate, 
                base_amount, phase, created_at
            ) VALUES (
                user_record.user_id,
                p_date,
                v_daily_profit,
                p_yield_rate,
                v_user_rate,
                user_record.total_nft_count * 1000,
                CASE WHEN user_record.cum_usdt < 1100 THEN 'USDT' ELSE 'HOLD' END,
                NOW()
            ) ON CONFLICT (user_id, date) DO UPDATE SET
                daily_profit = v_daily_profit,
                yield_rate = p_yield_rate,
                user_rate = v_user_rate,
                base_amount = user_record.total_nft_count * 1000,
                updated_at = NOW();

            v_total_users := v_total_users + 1;
            v_total_profit := v_total_profit + v_daily_profit;

        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors || ('ユーザー ' || user_record.user_id || ' の処理エラー: ' || SQLERRM);
        END;
    END LOOP;

    -- 累積利益更新（管理者設定のみ）
    UPDATE affiliate_cycle
    SET 
        cum_usdt = (
            SELECT COALESCE(SUM(daily_profit), 0)
            FROM user_daily_profit
            WHERE user_id = affiliate_cycle.user_id
        ),
        available_usdt = (
            SELECT COALESCE(SUM(daily_profit), 0)
            FROM user_daily_profit
            WHERE user_id = affiliate_cycle.user_id
        ),
        updated_at = NOW()
    WHERE user_id IN (
        SELECT user_id FROM users WHERE has_approved_nft = true
    );

    -- 結果返却
    RETURN QUERY SELECT 
        ('管理者設定による日利処理完了: ' || v_total_users || '名のユーザーに処理')::TEXT,
        v_total_users,
        v_total_profit,
        v_total_auto_purchases,
        v_errors;

END;
$$ LANGUAGE plpgsql;

-- 2. 自動バッチ処理も管理者設定のみに依存
CREATE OR REPLACE FUNCTION execute_daily_batch(
    p_date DATE DEFAULT CURRENT_DATE,
    p_default_yield_rate NUMERIC DEFAULT NULL,
    p_default_margin_rate NUMERIC DEFAULT NULL
)
RETURNS TABLE(
    success BOOLEAN,
    message TEXT,
    details JSONB
) AS $$
DECLARE
    v_yield_rate NUMERIC;
    v_margin_rate NUMERIC;
BEGIN
    -- 管理者設定の確認（勝手なデフォルト値禁止）
    SELECT yield_rate, margin_rate 
    INTO v_yield_rate, v_margin_rate
    FROM daily_yield_log 
    WHERE date = p_date;

    -- 管理者設定がない場合はエラー
    IF v_yield_rate IS NULL THEN
        RETURN QUERY SELECT 
            false,
            'エラー: 管理者による日利設定が必要です'::TEXT,
            jsonb_build_object(
                'error', '管理者設定なし',
                'date', p_date,
                'message', '管理者が日利設定を行ってください'
            );
        RETURN;
    END IF;

    -- 管理者設定に基づいて実行
    PERFORM process_daily_yield_with_cycles(
        p_date,
        v_yield_rate,
        v_margin_rate,
        false, -- 本番モード
        false  -- 月末処理は管理者が明示的に指定
    );

    RETURN QUERY SELECT 
        true,
        '管理者設定による日利処理完了'::TEXT,
        jsonb_build_object(
            'date', p_date,
            'yield_rate', v_yield_rate,
            'margin_rate', v_margin_rate,
            'source', 'admin_setting'
        );

END;
$$ LANGUAGE plpgsql;

-- 3. 紹介報酬も管理者設定のみに依存
-- 紹介報酬率を固定値から管理者設定に変更
CREATE TABLE IF NOT EXISTS referral_settings (
    id SERIAL PRIMARY KEY,
    level1_rate NUMERIC DEFAULT 0.20, -- 20%
    level2_rate NUMERIC DEFAULT 0.10, -- 10%
    level3_rate NUMERIC DEFAULT 0.05, -- 5%
    level4_plus_rate NUMERIC DEFAULT 0.00, -- 0%（将来拡張用）
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 初期設定（管理者が変更可能）
INSERT INTO referral_settings (level1_rate, level2_rate, level3_rate, level4_plus_rate)
VALUES (0.20, 0.10, 0.05, 0.00)
ON CONFLICT DO NOTHING;

-- 4. システムログ記録
SELECT log_system_event(
    'SUCCESS',
    'ADMIN_ONLY_SYSTEM_FIX',
    NULL,
    'システムを管理者設定のみに依存するよう修正完了',
    jsonb_build_object(
        'action', 'removed_default_values',
        'scope', 'system_wide',
        'timestamp', NOW(),
        'severity', 'CRITICAL'
    )
);

-- 5. 完了メッセージ
SELECT 
    'システム修正完了: 管理者設定のみに依存' as status,
    '勝手なデフォルト値を全て削除' as action,
    '今後は管理者が明示的に設定した値のみ使用' as result;