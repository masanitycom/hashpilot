-- 管理者権限チェックを修正して、admin_post_yield関数を更新

CREATE OR REPLACE FUNCTION admin_post_yield(
    p_date DATE,
    p_yield_rate DECIMAL(5,4),
    p_margin_rate DECIMAL(3,2),
    p_is_month_end BOOLEAN DEFAULT FALSE
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_count INTEGER := 0;
    v_total_user_profit DECIMAL(15,2) := 0;
    v_total_company_profit DECIMAL(15,2) := 0;
    v_user_rate DECIMAL(5,4);
    v_user_record RECORD;
    v_profit_amount DECIMAL(15,2);
    v_margin_amount DECIMAL(15,2);
    v_current_user_email TEXT;
BEGIN
    -- 現在のユーザーのメールアドレスを取得
    SELECT auth.email() INTO v_current_user_email;
    
    -- 管理者権限チェック（メールアドレスベース）
    IF v_current_user_email IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;
    
    -- 管理者テーブルから権限確認（存在しない場合はスキップ）
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'admins') THEN
        IF NOT EXISTS (
            SELECT 1 FROM admins 
            WHERE email = v_current_user_email 
            AND is_active = TRUE
        ) THEN
            -- 特定の管理者メールアドレスを許可（テスト用）
            IF v_current_user_email NOT IN (
                'admin@hashpilot.com',
                'test@hashpilot.com',
                'hashpilot.admin@gmail.com'
            ) THEN
                RAISE EXCEPTION 'Admin access required';
            END IF;
        END IF;
    END IF;
    
    -- 既に同じ日付で投稿されているかチェック
    IF EXISTS (SELECT 1 FROM daily_yield_log WHERE date = p_date) THEN
        RAISE EXCEPTION 'Yield already posted for date: %', p_date;
    END IF;
    
    -- ユーザー利率を計算
    v_user_rate := p_yield_rate * (1 - p_margin_rate);
    
    -- アクティブなユーザーの投資額を取得して利益を計算
    FOR v_user_record IN 
        SELECT 
            u.id,
            u.email,
            COALESCE(u.total_investment, 0) as investment_amount
        FROM users u
        WHERE u.is_active = TRUE 
        AND u.has_approved_nft = TRUE
        AND COALESCE(u.total_investment, 0) > 0
    LOOP
        -- ユーザーの日利を計算
        v_profit_amount := v_user_record.investment_amount * v_user_rate;
        v_margin_amount := v_user_record.investment_amount * p_yield_rate * p_margin_rate;
        
        -- ユーザー日利テーブルに記録
        INSERT INTO user_daily_profit (
            user_id,
            date,
            investment_amount,
            yield_rate,
            profit_amount,
            created_at
        ) VALUES (
            v_user_record.id,
            p_date,
            v_user_record.investment_amount,
            v_user_rate,
            v_profit_amount,
            NOW()
        );
        
        -- 集計値を更新
        v_user_count := v_user_count + 1;
        v_total_user_profit := v_total_user_profit + v_profit_amount;
        v_total_company_profit := v_total_company_profit + v_margin_amount;
    END LOOP;
    
    -- 日利ログに記録
    INSERT INTO daily_yield_log (
        date,
        yield_rate,
        margin_rate,
        user_rate,
        is_month_end,
        total_users,
        total_profit,
        created_at
    ) VALUES (
        p_date,
        p_yield_rate,
        p_margin_rate,
        v_user_rate,
        p_is_month_end,
        v_user_count,
        v_total_user_profit,
        NOW()
    );
    
    -- 会社日利テーブルに記録
    INSERT INTO company_daily_profit (
        date,
        total_margin,
        total_company_profit,
        user_count,
        total_user_profit,
        created_at
    ) VALUES (
        p_date,
        v_total_company_profit,
        v_total_company_profit,
        v_user_count,
        v_total_user_profit,
        NOW()
    );
    
    -- アフィリエイト報酬の計算と配布
    PERFORM calculate_affiliate_rewards(p_date);
    
    -- 結果を返す
    RETURN json_build_object(
        'success', TRUE,
        'date', p_date,
        'yield_rate', p_yield_rate,
        'user_rate', v_user_rate,
        'total_users', v_user_count,
        'total_user_profit', v_total_user_profit,
        'total_company_profit', v_total_company_profit
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error in admin_post_yield: %', SQLERRM;
END;
$$;
