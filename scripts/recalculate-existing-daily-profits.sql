-- 既存の日利データを新しいシステムで再計算
-- 7/6-7/10の設定済み日利を正しい計算で更新

-- 既存データを新しいシステムで再計算
DO $$
DECLARE
    daily_record RECORD;
    result_record RECORD;
BEGIN
    -- 設定済みの各日付の日利を新しいシステムで再計算
    FOR daily_record IN 
        SELECT DISTINCT date, yield_rate, margin_rate 
        FROM daily_yield_log 
        WHERE date >= '2025-07-06' AND date <= '2025-07-10'
        ORDER BY date
    LOOP
        RAISE NOTICE '再計算中: % (日利率: %)', daily_record.date, daily_record.yield_rate;
        
        -- 新しいシステムで再計算（本番モード）
        SELECT * INTO result_record 
        FROM process_daily_yield_with_cycles(
            daily_record.date::DATE,
            daily_record.yield_rate,
            daily_record.margin_rate,
            false  -- 本番モード
        );
        
        RAISE NOTICE '完了: % - %', daily_record.date, result_record.message;
    END LOOP;
    
    RAISE NOTICE '全ての既存日利データの再計算が完了しました';
END $$;

-- 再計算後の統計を表示
SELECT '=== 再計算後の統計 ===' as section;

-- 各日の利益サマリー
SELECT 
    date,
    COUNT(*) as users,
    SUM(daily_profit) as total_daily_profit,
    AVG(daily_profit) as avg_profit_per_user,
    SUM(personal_profit) as total_personal,
    SUM(referral_profit) as total_referral
FROM user_daily_profit 
WHERE date >= '2025-07-06' AND date <= '2025-07-10'
GROUP BY date
ORDER BY date;

-- 投資額別の利益比較
SELECT '=== 投資額別利益比較 ===' as section;
SELECT 
    u.total_purchases as investment,
    COUNT(*) as user_count,
    AVG(udp.personal_profit) as avg_personal_profit,
    AVG(udp.referral_profit) as avg_referral_profit,
    AVG(udp.daily_profit) as avg_total_profit
FROM users u
JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE udp.date = '2025-07-10'  -- 最新日のデータで比較
AND u.total_purchases > 0
GROUP BY u.total_purchases
ORDER BY u.total_purchases DESC;

-- 紹介報酬が発生しているユーザー
SELECT '=== 紹介報酬TOP10 ===' as section;
SELECT 
    u.user_id,
    u.email,
    u.total_purchases,
    udp.personal_profit,
    udp.referral_profit,
    udp.daily_profit as total_profit
FROM users u
JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE udp.date = '2025-07-10'
AND udp.referral_profit > 0
ORDER BY udp.referral_profit DESC
LIMIT 10;

SELECT '既存の日利データを新しいシステムで再計算しました。ダッシュボードを更新してください。' as message;