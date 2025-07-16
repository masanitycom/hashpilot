-- 🔍 ダッシュボードの日付問題を調査
-- 2025年7月17日

-- 1. 現在の日付を確認
SELECT 
    'current_date_check' as check_type,
    CURRENT_DATE as today,
    CURRENT_DATE - INTERVAL '1 day' as yesterday,
    CURRENT_TIMESTAMP as current_timestamp;

-- 2. 昨日（7/16）の7A9637のデータを確認
SELECT 
    'yesterday_7A9637_data' as check_type,
    user_id,
    date,
    daily_profit,
    personal_profit,
    referral_profit,
    phase,
    created_at
FROM user_daily_profit 
WHERE user_id = '7A9637' 
AND date = '2025-07-16';

-- 3. 昨日の全ユーザーの紹介報酬を確認
SELECT 
    'yesterday_all_referral' as check_type,
    user_id,
    date,
    daily_profit,
    personal_profit,
    referral_profit,
    phase
FROM user_daily_profit 
WHERE date = '2025-07-16'
AND referral_profit > 0
ORDER BY referral_profit DESC;

-- 4. 7A9637の最近の紹介報酬履歴
SELECT 
    '7A9637_recent_referral' as check_type,
    date,
    daily_profit,
    personal_profit,
    referral_profit,
    phase,
    created_at
FROM user_daily_profit 
WHERE user_id = '7A9637'
AND date >= '2025-07-10'
AND referral_profit > 0
ORDER BY date DESC;

-- 5. フロントエンドが参照する可能性のある日付範囲
SELECT 
    'frontend_date_range' as check_type,
    date,
    SUM(CASE WHEN referral_profit > 0 THEN referral_profit ELSE 0 END) as total_referral_profit,
    COUNT(*) as record_count
FROM user_daily_profit 
WHERE user_id = '7A9637'
AND date >= '2025-07-15'
GROUP BY date
ORDER BY date DESC;