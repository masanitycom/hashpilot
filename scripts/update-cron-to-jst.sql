-- 月末処理のcronジョブを日本時間23:59に変更

-- 現在のcronジョブを確認
SELECT 
    jobname,
    schedule,
    command,
    active
FROM cron.job
WHERE jobname LIKE '%monthly%' OR jobname LIKE '%withdrawal%';

-- 既存のcronジョブを削除（もしあれば）
SELECT cron.unschedule('monthly_withdrawal_process');

-- 新しいcronジョブを作成（日本時間23:59 = UTC 14:59）
-- 毎月最終日の14:59 UTCに実行
SELECT cron.schedule(
    'monthly_withdrawal_process',
    '59 14 28-31 * *', -- 28-31日の14:59 UTCに実行
    $$
    DO $$
    DECLARE
        v_last_day DATE;
        v_today DATE;
    BEGIN
        -- 現在の日付（日本時間）を取得
        v_today := (NOW() AT TIME ZONE 'Asia/Tokyo')::DATE;
        
        -- 当月の最終日を取得
        v_last_day := DATE_TRUNC('month', v_today) + INTERVAL '1 month' - INTERVAL '1 day';
        
        -- 今日が月末の場合のみ実行
        IF v_today = v_last_day THEN
            -- available_usdtを使用した月末自動出金処理
            INSERT INTO withdrawals (
                user_id,
                email,
                amount,
                status,
                withdrawal_type,
                created_at,
                notes
            )
            SELECT 
                ac.user_id,
                u.email,
                ac.available_usdt,
                'pending',
                'monthly_auto',
                NOW(),
                '月末自動出金 - ' || TO_CHAR(v_today, 'YYYY年MM月')
            FROM affiliate_cycle ac
            JOIN users u ON ac.user_id = u.user_id
            WHERE ac.available_usdt >= 100  -- 最低出金額100 USDT
            AND NOT EXISTS (
                -- 同月の自動出金申請が既に存在しないかチェック
                SELECT 1 
                FROM withdrawals w 
                WHERE w.user_id = ac.user_id 
                AND w.withdrawal_type = 'monthly_auto'
                AND DATE_TRUNC('month', w.created_at) = DATE_TRUNC('month', v_today)
            );
            
            -- available_usdtをリセット
            UPDATE affiliate_cycle
            SET 
                available_usdt = 0,
                last_updated = NOW()
            WHERE user_id IN (
                SELECT user_id 
                FROM withdrawals 
                WHERE withdrawal_type = 'monthly_auto'
                AND DATE_TRUNC('month', created_at) = DATE_TRUNC('month', v_today)
                AND status = 'pending'
            );
            
            -- ログ記録
            INSERT INTO system_logs (
                log_type,
                message,
                created_at
            )
            VALUES (
                'monthly_withdrawal',
                '月末自動出金処理完了: ' || 
                (SELECT COUNT(*) FROM withdrawals 
                 WHERE withdrawal_type = 'monthly_auto' 
                 AND DATE_TRUNC('month', created_at) = DATE_TRUNC('month', v_today)) || 
                '件の申請を作成',
                NOW()
            );
        END IF;
    END $$;
    $$
);

-- cronジョブが正しく登録されたか確認
SELECT 
    jobname,
    schedule,
    command,
    active
FROM cron.job
WHERE jobname = 'monthly_withdrawal_process';

-- 注意事項：
-- 1. このcronジョブは28-31日の毎日14:59 UTC（日本時間23:59）に実行されます
-- 2. ジョブ内で実際の月末かどうかをチェックして、月末の場合のみ処理を実行します
-- 3. 100 USDT以上のavailable_usdtを持つユーザーのみ対象です
-- 4. 出金申請作成後、available_usdtは0にリセットされます