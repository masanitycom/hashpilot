-- 管理画面で簡単確認用

-- Y9FVT1の今日の状況
SELECT 
    'torucajino@gmail.com (Y9FVT1)' as user_info,
    '今月の累積利益: $' || COALESCE(SUM(daily_profit::DECIMAL), 0) as monthly_profit,
    '利益日数: ' || COUNT(*) || '日' as profit_days
FROM user_daily_profit 
WHERE user_id = 'Y9FVT1' 
AND date >= DATE_TRUNC('month', CURRENT_DATE);