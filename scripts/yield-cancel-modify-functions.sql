-- 日利設定の取消・修正機能

-- 1. 日利投稿取消関数
CREATE OR REPLACE FUNCTION cancel_yield_posting(
    p_date DATE
) RETURNS JSON AS $$
DECLARE
    v_affected_users INTEGER;
    v_deleted_profits DECIMAL(12,2);
    v_result JSON;
BEGIN
    -- 管理者権限チェック
    IF NOT EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text) THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;
    
    -- 既存の日利投稿があるかチェック
    IF NOT EXISTS (SELECT 1 FROM daily_yield_log WHERE date = p_date) THEN
        RAISE EXCEPTION '指定日の日利投稿が見つかりません: %', p_date;
    END IF;
    
    -- 影響を受けるユーザー数と削除される利益額を計算
    SELECT 
        COUNT(*),
        COALESCE(SUM(daily_profit), 0)
    INTO v_affected_users, v_deleted_profits
    FROM user_daily_profit
    WHERE date = p_date;
    
    -- 関連データを削除（逆順で削除）
    -- 1. 紹介報酬を削除
    DELETE FROM affiliate_reward WHERE date = p_date;
    
    -- 2. ユーザー日利を削除
    DELETE FROM user_daily_profit WHERE date = p_date;
    
    -- 3. 会社利益を削除
    DELETE FROM company_daily_profit WHERE date = p_date;
    
    -- 4. 日利ログを削除
    DELETE FROM daily_yield_log WHERE date = p_date;
    
    v_result := json_build_object(
        'success', true,
        'message', format('%s の日利投稿をキャンセルしました', p_date),
        'affected_users', v_affected_users,
        'deleted_profits', v_deleted_profits,
        'cancelled_by', auth.uid(),
        'cancelled_at', NOW()
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. 日利投稿修正関数
CREATE OR REPLACE FUNCTION modify_yield_posting(
    p_date DATE,
    p_new_yield_rate DECIMAL(5,4),
    p_new_margin_rate DECIMAL(3,2),
    p_new_is_month_end BOOLEAN DEFAULT FALSE
) RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    -- 管理者権限チェック
    IF NOT EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text) THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;
    
    -- 既存の日利投稿があるかチェック
    IF NOT EXISTS (SELECT 1 FROM daily_yield_log WHERE date = p_date) THEN
        RAISE EXCEPTION '指定日の日利投稿が見つかりません: %', p_date;
    END IF;
    
    -- 既存データを削除してから新しいデータで再計算
    PERFORM cancel_yield_posting(p_date);
    
    -- 新しい設定で再投稿
    SELECT admin_post_yield(p_date, p_new_yield_rate, p_new_margin_rate, p_new_is_month_end)
    INTO v_result;
    
    -- 結果に修正情報を追加
    v_result := v_result || json_build_object(
        'modified', true,
        'original_action', 'modify_yield_posting',
        'modified_by', auth.uid(),
        'modified_at', NOW()
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. 日利投稿履歴表示関数
CREATE OR REPLACE FUNCTION get_yield_posting_history(
    p_limit INTEGER DEFAULT 30
) RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    -- 管理者権限チェック
    IF NOT EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text) THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;
    
    SELECT json_agg(
        json_build_object(
            'date', dyl.date,
            'yield_rate', dyl.yield_rate,
            'margin_rate', dyl.margin_rate,
            'user_rate', dyl.user_rate,
            'is_month_end', dyl.is_month_end,
            'created_at', dyl.created_at,
            'created_by', dyl.created_by,
            'users_affected', cdp.user_count,
            'total_user_profit', cdp.total_user_profit,
            'total_company_profit', cdp.total_company_profit,
            'can_cancel', (dyl.date >= CURRENT_DATE - INTERVAL '7 days') -- 7日以内は取消可能
        ) ORDER BY dyl.date DESC
    )
    INTO v_result
    FROM daily_yield_log dyl
    LEFT JOIN company_daily_profit cdp ON dyl.date = cdp.date
    ORDER BY dyl.date DESC
    LIMIT p_limit;
    
    RETURN COALESCE(v_result, '[]'::json);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. 日利投稿の影響確認関数（削除前の確認用）
CREATE OR REPLACE FUNCTION check_yield_posting_impact(
    p_date DATE
) RETURNS JSON AS $$
DECLARE
    v_result JSON;
    v_user_count INTEGER;
    v_total_profit DECIMAL(12,2);
    v_total_affiliate DECIMAL(12,2);
    v_is_recent BOOLEAN;
BEGIN
    -- 管理者権限チェック
    IF NOT EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text) THEN
        RAISE EXCEPTION 'Admin access required';
    END IF;
    
    -- 日利投稿の存在確認
    IF NOT EXISTS (SELECT 1 FROM daily_yield_log WHERE date = p_date) THEN
        RAISE EXCEPTION '指定日の日利投稿が見つかりません: %', p_date;
    END IF;
    
    -- 影響するユーザー数と利益額を計算
    SELECT 
        COUNT(*),
        COALESCE(SUM(daily_profit), 0)
    INTO v_user_count, v_total_profit
    FROM user_daily_profit
    WHERE date = p_date;
    
    -- 紹介報酬総額を計算
    SELECT 
        COALESCE(SUM(reward_amount), 0)
    INTO v_total_affiliate
    FROM affiliate_reward
    WHERE date = p_date;
    
    -- 最近の投稿かどうか判定（7日以内）
    v_is_recent := (p_date >= CURRENT_DATE - INTERVAL '7 days');
    
    v_result := json_build_object(
        'date', p_date,
        'can_cancel', v_is_recent,
        'affected_users', v_user_count,
        'total_user_profit', v_total_profit,
        'total_affiliate_rewards', v_total_affiliate,
        'warning_message', CASE 
            WHEN NOT v_is_recent THEN '7日以上前の投稿は取消できません'
            WHEN v_user_count > 0 THEN format('%s名のユーザーの利益 $%s が削除されます', v_user_count, v_total_profit)
            ELSE 'この投稿による利益配布はありません'
        END
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. RLS設定
ALTER TABLE test_daily_yield_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE test_user_daily_profit ENABLE ROW LEVEL SECURITY;
ALTER TABLE test_affiliate_reward ENABLE ROW LEVEL SECURITY;
ALTER TABLE test_company_daily_profit ENABLE ROW LEVEL SECURITY;

-- 管理者のみアクセス可能
CREATE POLICY "test_tables_admin_only" ON test_daily_yield_log FOR ALL 
USING (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text));

CREATE POLICY "test_user_profit_admin_only" ON test_user_daily_profit FOR ALL 
USING (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text));

CREATE POLICY "test_affiliate_reward_admin_only" ON test_affiliate_reward FOR ALL 
USING (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text));

CREATE POLICY "test_company_profit_admin_only" ON test_company_daily_profit FOR ALL 
USING (EXISTS (SELECT 1 FROM admins WHERE user_id = auth.uid()::text));

COMMENT ON FUNCTION cancel_yield_posting IS '日利投稿を取消（7日以内のみ）';
COMMENT ON FUNCTION modify_yield_posting IS '日利投稿を修正（取消してから再投稿）';
COMMENT ON FUNCTION get_yield_posting_history IS '日利投稿履歴を取得';
COMMENT ON FUNCTION check_yield_posting_impact IS '日利投稿の影響を確認（削除前チェック用）';