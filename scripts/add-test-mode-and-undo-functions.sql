-- テストモード用の日利投稿関数（データベースに保存しない）
CREATE OR REPLACE FUNCTION admin_post_yield_test_mode(
    p_date DATE,
    p_yield_rate NUMERIC(5,4),
    p_margin_rate NUMERIC(5,4),
    p_is_month_end BOOLEAN DEFAULT FALSE
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_total_users INTEGER := 0;
    v_total_user_profit NUMERIC(15,2) := 0;
    v_total_company_profit NUMERIC(15,2) := 0;
    v_total_base_amount NUMERIC(15,2) := 0;
    v_user_rate NUMERIC(5,4);
    v_result JSON;
    v_user_record RECORD;
    v_user_investment NUMERIC(15,2);
    v_user_profit NUMERIC(15,2);
    v_company_profit NUMERIC(15,2);
BEGIN
    -- ユーザー利率を計算
    v_user_rate := p_yield_rate * (1 - p_margin_rate);
    
    -- アクティブなNFT承認済みユーザーを取得して計算のみ実行
    FOR v_user_record IN 
        SELECT 
            u.user_id,
            u.id as auth_id,
            COALESCE(SUM(p.amount_usd::DECIMAL(15,2)), 0) as total_investment
        FROM users u
        LEFT JOIN purchases p ON u.user_id = p.user_id 
            AND p.payment_status = 'approved' 
            AND p.admin_approved = TRUE
        WHERE u.is_active = TRUE 
            AND u.has_approved_nft = TRUE
        GROUP BY u.user_id, u.id
        HAVING COALESCE(SUM(p.amount_usd::DECIMAL(15,2)), 0) > 0
    LOOP
        v_user_investment := v_user_record.total_investment;
        v_user_profit := v_user_investment * v_user_rate;
        v_company_profit := v_user_investment * p_margin_rate;
        
        -- 合計に加算（実際の保存は行わない）
        v_total_users := v_total_users + 1;
        v_total_user_profit := v_total_user_profit + v_user_profit;
        v_total_company_profit := v_total_company_profit + v_company_profit;
        v_total_base_amount := v_total_base_amount + v_user_investment;
    END LOOP;
    
    -- 結果をJSONで返す（テストモード）
    v_result := json_build_object(
        'success', true,
        'test_mode', true,
        'date', p_date,
        'yield_rate', p_yield_rate,
        'margin_rate', p_margin_rate,
        'user_rate', v_user_rate,
        'total_users', v_total_users,
        'total_user_profit', v_total_user_profit,
        'total_company_profit', v_total_company_profit,
        'total_base_amount', v_total_base_amount,
        'message', 'テストモード: 計算のみ実行、データベースには保存されていません'
    );
    
    RETURN v_result;
END;
$$;

-- 日利投稿をキャンセルする関数
CREATE OR REPLACE FUNCTION cancel_yield_posting(p_date DATE)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_yield_log_id INTEGER;
    v_affected_users INTEGER := 0;
    v_total_reversed NUMERIC(15,2) := 0;
    v_user_record RECORD;
    v_result JSON;
BEGIN
    -- 管理者権限チェック
    IF NOT EXISTS (
        SELECT 1 FROM admins 
        WHERE email = auth.email() 
        AND is_active = TRUE
    ) AND auth.email() NOT IN (
        'basarasystems@gmail.com',
        'masataka.tak@gmail.com', 
        'admin@hashpilot.com',
        'test@hashpilot.com',
        'hashpilot.admin@gmail.com'
    ) THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;
    
    -- 指定日の日利ログを取得
    SELECT id INTO v_yield_log_id
    FROM daily_yield_log
    WHERE date = p_date;
    
    IF v_yield_log_id IS NULL THEN
        RAISE EXCEPTION '指定された日付の日利投稿が見つかりません: %', p_date;
    END IF;
    
    -- その日のユーザー日利記録を取得してユーザーの残高から差し引く
    FOR v_user_record IN 
        SELECT user_id, total_user_profit
        FROM user_daily_profit
        WHERE date = p_date
    LOOP
        -- ユーザーの累積利益から差し引く
        UPDATE users 
        SET total_referral_earnings = GREATEST(0, total_referral_earnings - v_user_record.total_user_profit)
        WHERE user_id = v_user_record.user_id;
        
        v_affected_users := v_affected_users + 1;
        v_total_reversed := v_total_reversed + v_user_record.total_user_profit;
    END LOOP;
    
    -- 関連データを削除
    DELETE FROM user_daily_profit WHERE date = p_date;
    DELETE FROM company_daily_profit WHERE date = p_date;
    DELETE FROM daily_yield_log WHERE date = p_date;
    
    v_result := json_build_object(
        'success', true,
        'message', format('%s の日利投稿をキャンセルしました。%s名のユーザーから総額$%s を差し引きました。', 
                         p_date, v_affected_users, v_total_reversed),
        'affected_users', v_affected_users,
        'total_reversed', v_total_reversed
    );
    
    RETURN v_result;
END;
$$;

-- 管理者一覧を表示する関数
CREATE OR REPLACE FUNCTION get_admin_list()
RETURNS TABLE(email TEXT, is_active BOOLEAN, created_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT a.email, a.is_active, a.created_at
    FROM admins a
    ORDER BY a.created_at DESC;
END;
$$;
