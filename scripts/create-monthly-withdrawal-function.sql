-- 月末自動出金処理用の関数を作成（手動実行またはSupabase Dashboardのスケジューラーから実行）

-- 1. 月末自動出金処理関数
CREATE OR REPLACE FUNCTION process_monthly_auto_withdrawal()
RETURNS TABLE (
    processed_count INTEGER,
    total_amount NUMERIC,
    message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_processed_count INTEGER := 0;
    v_total_amount NUMERIC := 0;
    v_today DATE;
    v_last_day DATE;
    v_user_record RECORD;
BEGIN
    -- 日本時間での現在日付を取得
    v_today := (NOW() AT TIME ZONE 'Asia/Tokyo')::DATE;
    
    -- 当月の最終日を取得
    v_last_day := DATE_TRUNC('month', v_today) + INTERVAL '1 month' - INTERVAL '1 day';
    
    -- 今日が月末でない場合はエラー
    IF v_today != v_last_day THEN
        RETURN QUERY
        SELECT 
            0::INTEGER,
            0::NUMERIC,
            '本日は月末ではありません。処理をスキップします。'::TEXT;
        RETURN;
    END IF;
    
    -- 月末処理実行
    FOR v_user_record IN
        SELECT 
            ac.user_id,
            u.email,
            ac.available_usdt,
            uws.withdrawal_address,
            uws.coinw_uid
        FROM affiliate_cycle ac
        JOIN users u ON ac.user_id = u.user_id
        LEFT JOIN user_withdrawal_settings uws ON ac.user_id = uws.user_id
        WHERE ac.available_usdt >= 100  -- 最低出金額100 USDT
        AND NOT EXISTS (
            -- 同月の自動出金申請が既に存在しないかチェック
            SELECT 1 
            FROM withdrawals w 
            WHERE w.user_id = ac.user_id 
            AND w.withdrawal_type = 'monthly_auto'
            AND DATE_TRUNC('month', w.created_at AT TIME ZONE 'Asia/Tokyo') = DATE_TRUNC('month', v_today)
        )
    LOOP
        -- 出金申請を作成
        INSERT INTO withdrawals (
            user_id,
            email,
            amount,
            status,
            withdrawal_type,
            withdrawal_address,
            coinw_uid,
            created_at,
            notes
        )
        VALUES (
            v_user_record.user_id,
            v_user_record.email,
            v_user_record.available_usdt,
            'pending',
            'monthly_auto',
            v_user_record.withdrawal_address,
            v_user_record.coinw_uid,
            NOW(),
            '月末自動出金 - ' || TO_CHAR(v_today, 'YYYY年MM月')
        );
        
        -- available_usdtをリセット
        UPDATE affiliate_cycle
        SET 
            available_usdt = 0,
            last_updated = NOW()
        WHERE user_id = v_user_record.user_id;
        
        v_processed_count := v_processed_count + 1;
        v_total_amount := v_total_amount + v_user_record.available_usdt;
    END LOOP;
    
    -- ログ記録（system_logsテーブルが存在する場合）
    BEGIN
        INSERT INTO system_logs (
            log_type,
            message,
            created_at
        )
        VALUES (
            'monthly_withdrawal',
            '月末自動出金処理完了: ' || v_processed_count || '件、総額: $' || v_total_amount,
            NOW()
        );
    EXCEPTION WHEN undefined_table THEN
        -- system_logsテーブルが存在しない場合は無視
        NULL;
    END;
    
    RETURN QUERY
    SELECT 
        v_processed_count,
        v_total_amount,
        ('月末自動出金処理が完了しました。' || v_processed_count || '件の申請を作成、総額: $' || v_total_amount)::TEXT;
END;
$$;

-- 2. 手動実行用のテスト関数（月末でなくても実行可能）
CREATE OR REPLACE FUNCTION test_monthly_auto_withdrawal(p_force BOOLEAN DEFAULT false)
RETURNS TABLE (
    user_id TEXT,
    email TEXT,
    available_usdt NUMERIC,
    withdrawal_address TEXT,
    coinw_uid TEXT,
    would_process BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ac.user_id,
        u.email,
        ac.available_usdt,
        uws.withdrawal_address,
        uws.coinw_uid,
        (ac.available_usdt >= 100)::BOOLEAN as would_process
    FROM affiliate_cycle ac
    JOIN users u ON ac.user_id = u.user_id
    LEFT JOIN user_withdrawal_settings uws ON ac.user_id = uws.user_id
    WHERE ac.available_usdt > 0
    ORDER BY ac.available_usdt DESC;
END;
$$;

-- 3. 月末チェック関数
CREATE OR REPLACE FUNCTION is_month_end_jst()
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_today DATE;
    v_last_day DATE;
BEGIN
    -- 日本時間での現在日付を取得
    v_today := (NOW() AT TIME ZONE 'Asia/Tokyo')::DATE;
    
    -- 当月の最終日を取得
    v_last_day := DATE_TRUNC('month', v_today) + INTERVAL '1 month' - INTERVAL '1 day';
    
    RETURN v_today = v_last_day;
END;
$$;

-- 使用方法：
-- 1. テスト実行（どのユーザーが対象になるか確認）
-- SELECT * FROM test_monthly_auto_withdrawal();

-- 2. 本番実行（月末のみ実行可能）
-- SELECT * FROM process_monthly_auto_withdrawal();

-- 3. 月末かどうかチェック
-- SELECT is_month_end_jst();