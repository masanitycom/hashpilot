-- 🔍 7/17の処理確認
-- 2025年7月17日

-- 1. 7/17の日利設定確認
SELECT 
    '7/17日利設定' as check_type,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
FROM daily_yield_log 
WHERE date = '2025-07-17'
ORDER BY created_at DESC;

-- 2. 7/17のシステムログ確認
SELECT 
    '7/17システムログ' as check_type,
    log_type,
    operation,
    message,
    details,
    created_at
FROM system_logs 
WHERE DATE(created_at) = '2025-07-17'
AND operation LIKE '%daily_yield%'
ORDER BY created_at DESC;

-- 3. 7/17の日利記録確認
SELECT 
    '7/17日利記録' as check_type,
    user_id,
    date,
    daily_profit,
    personal_profit,
    referral_profit,
    base_amount,
    phase,
    created_at
FROM user_daily_profit 
WHERE date = '2025-07-17'
ORDER BY created_at DESC;

-- 4. B43A3Dの7/17処理確認
SELECT 
    'B43A3D_7/17処理' as check_type,
    user_id,
    date,
    daily_profit,
    personal_profit,
    referral_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    created_at
FROM user_daily_profit 
WHERE user_id = 'B43A3D'
AND date = '2025-07-17';

-- 5. 7A9637の7/17紹介報酬確認
SELECT 
    '7A9637_7/17紹介報酬' as check_type,
    user_id,
    date,
    daily_profit,
    personal_profit,
    referral_profit,
    base_amount,
    phase,
    created_at
FROM user_daily_profit 
WHERE user_id = '7A9637'
AND date = '2025-07-17';

-- 6. 6E1304の7/17紹介報酬確認  
SELECT 
    '6E1304_7/17紹介報酬' as check_type,
    user_id,
    date,
    daily_profit,
    personal_profit,
    referral_profit,
    base_amount,
    phase,
    created_at
FROM user_daily_profit 
WHERE user_id = '6E1304'
AND date = '2025-07-17';

-- 7. 今日の最新システムログ確認
SELECT 
    '今日の最新ログ' as check_type,
    log_type,
    operation,
    message,
    details,
    created_at
FROM system_logs 
WHERE DATE(created_at) = CURRENT_DATE
ORDER BY created_at DESC
LIMIT 5;