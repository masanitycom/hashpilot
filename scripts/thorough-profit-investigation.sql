-- 🔍 2BF53Bと他ユーザーの利益状況徹底調査
-- 2025年1月16日

-- 1. 2BF53Bの詳細な利益記録
SELECT 
    '=== 2BF53Bの利益記録詳細 ===' as investigation,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    created_at,
    -- 承認日から何日後か
    date - '2025-06-17'::date as days_from_approval,
    -- 運用開始日から何日後か
    date - '2025-07-02'::date as days_from_operation_start
FROM user_daily_profit 
WHERE user_id = '2BF53B'
ORDER BY date;

-- 2. 2BF53Bの日利設定との照合
SELECT 
    '=== 2BF53Bの利益と日利設定照合 ===' as investigation,
    udp.date,
    udp.daily_profit,
    udp.user_rate as recorded_rate,
    dyl.user_rate as setting_rate,
    dyl.yield_rate as setting_yield_rate,
    dyl.margin_rate as setting_margin_rate,
    CASE 
        WHEN dyl.date IS NULL THEN '🚨 設定なし'
        WHEN udp.user_rate != dyl.user_rate THEN '🚨 利率不一致'
        ELSE '正常'
    END as status
FROM user_daily_profit udp
LEFT JOIN daily_yield_log dyl ON udp.date = dyl.date
WHERE udp.user_id = '2BF53B'
ORDER BY udp.date;

-- 3. 運用中の他ユーザーの利益状況確認
SELECT 
    '=== 運用中ユーザーの利益状況 ===' as investigation,
    u.user_id,
    u.email,
    MIN(p.admin_approved_at)::date as approval_date,
    MIN(p.admin_approved_at)::date + 15 as operation_start_date,
    CASE 
        WHEN MIN(p.admin_approved_at)::date + 15 <= CURRENT_DATE THEN '運用中'
        ELSE '運用前'
    END as expected_status,
    ac.total_nft_count,
    ac.cum_usdt,
    COUNT(udp.date) as profit_days,
    COALESCE(SUM(udp.daily_profit), 0) as calculated_total_profit
FROM users u
JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.has_approved_nft = true
GROUP BY u.user_id, u.email, ac.total_nft_count, ac.cum_usdt
HAVING MIN(p.admin_approved_at)::date + 15 <= CURRENT_DATE -- 運用中のみ
ORDER BY MIN(p.admin_approved_at);

-- 4. 7/2に利益が発生した理由の調査
SELECT 
    '=== 7/2の日利設定確認 ===' as investigation,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at,
    '2BF53Bの運用開始日' as note
FROM daily_yield_log 
WHERE date = '2025-07-02';

-- 5. 7/2から現在までの日利設定状況
SELECT 
    '=== 7/2以降の日利設定状況 ===' as investigation,
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
FROM daily_yield_log 
WHERE date >= '2025-07-02'
ORDER BY date;

-- 6. 利益が0のユーザーの詳細確認
SELECT 
    '=== 利益0ユーザーの詳細 ===' as investigation,
    u.user_id,
    u.email,
    p.admin_approved_at,
    p.admin_approved_at::date + 15 as operation_start_date,
    CASE 
        WHEN p.admin_approved_at::date + 15 <= CURRENT_DATE THEN '運用中のはず'
        ELSE '運用前'
    END as expected_status,
    ac.total_nft_count,
    ac.cum_usdt,
    CASE 
        WHEN ac.user_id IS NULL THEN '🚨 affiliate_cycleなし'
        WHEN ac.total_nft_count = 0 THEN '🚨 NFT数0'
        WHEN ac.cum_usdt = 0 THEN '🚨 利益0'
        ELSE '正常'
    END as problem_type
FROM users u
JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.has_approved_nft = true
AND p.admin_approved_at::date + 15 <= CURRENT_DATE -- 運用中のはず
AND (ac.cum_usdt = 0 OR ac.cum_usdt IS NULL)
ORDER BY p.admin_approved_at;

-- 7. 2BF53Bと同時期承認ユーザーとの比較
SELECT 
    '=== 2BF53Bと同時期ユーザーの比較 ===' as investigation,
    u.user_id,
    u.email,
    p.admin_approved_at,
    p.nft_quantity,
    ac.total_nft_count,
    ac.cum_usdt,
    COUNT(udp.date) as profit_days,
    CASE 
        WHEN ac.cum_usdt > 0 THEN '利益あり'
        ELSE '利益なし'
    END as profit_status
FROM users u
JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.has_approved_nft = true
AND p.admin_approved_at::date BETWEEN '2025-06-15' AND '2025-06-25' -- 2BF53B前後
GROUP BY u.user_id, u.email, p.admin_approved_at, p.nft_quantity, ac.total_nft_count, ac.cum_usdt
ORDER BY p.admin_approved_at;

-- 8. 利益処理関数の実行履歴
SELECT 
    '=== 利益処理関数の実行履歴 ===' as investigation,
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
FROM system_logs 
WHERE operation LIKE '%yield%' 
   OR operation LIKE '%profit%'
   OR operation LIKE '%daily%'
   OR message LIKE '%利益%'
ORDER BY created_at DESC
LIMIT 20;