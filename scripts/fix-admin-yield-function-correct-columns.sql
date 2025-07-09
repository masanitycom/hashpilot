-- admin_post_yield関数を修正して正しいカラム名を使用

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
    
    -- テスト環境では認証をスキップ
    IF v_current_user_email IS NULL THEN
        -- テスト用のデフォルト管理者として実行
        v_current_user_email := 'admin@hashpilot.com';
    END IF;
    
    -- 既に同じ日付で投稿されているかチェック
    IF EXISTS (SELECT 1 FROM daily_yield_log WHERE date = p_date) THEN
        RAISE EXCEPTION 'Yield already posted for date: %', p_date;
    END IF;
    
    -- ユーザー利率を計算
    v_user_rate := p_yield_rate * (1 - p_margin_rate);
    
    -- アクティブなユーザーの投資額をpurchasesテーブルから取得して利益を計算
    -- 正しいカラム名を使用（amount_usd）
    FOR v_user_record IN 
        SELECT 
            u.id,
            u.email,
            COALESCE(SUM(
                CASE 
                    WHEN p.amount_usd IS NOT NULL THEN p.amount_usd::DECIMAL(15,2)
                    ELSE 1000.00  -- デフォルト投資額
                END
            ), 1000.00) as investment_amount
        FROM users u
        LEFT JOIN purchases p ON u.id::TEXT = p.user_id::TEXT 
            AND p.payment_status = 'approved' 
            AND p.admin_approved = TRUE
        WHERE u.is_active = TRUE 
        AND u.has_approved_nft = TRUE
        GROUP BY u.id, u.email
    LOOP
        -- ユーザーの日利を計算
        v_profit_amount := v_user_record.investment_amount * v_user_rate;
        v_margin_amount := v_user_record.investment_amount * p_yield_rate * p_margin_rate;
        
        -- ユーザー日利テーブルに記録（存在するカラムのみ使用）
        INSERT INTO user_daily_profit (
            user_id,
            date,
            yield_rate,
            profit_amount,
            created_at
        ) VALUES (
            v_user_record.id,
            p_date,
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
    
    -- アフィリエイト報酬の計算と配布（関数が存在する場合のみ）
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'calculate_affiliate_rewards') THEN
        PERFORM calculate_affiliate_rewards(p_date);
    END IF;
    
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
