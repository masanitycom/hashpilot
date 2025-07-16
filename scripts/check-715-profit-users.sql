-- 7/15に利益を受け取った5名の詳細調査

-- 1. 7/15に利益を受け取った全ユーザー
SELECT 
    '=== 7/15利益受取者詳細 ===' as investigation,
    udp.user_id,
    u.email,
    udp.daily_profit,
    udp.yield_rate,
    udp.user_rate,
    udp.base_amount,
    udp.created_at,
    ac.total_nft_count
FROM user_daily_profit udp
JOIN users u ON udp.user_id = u.user_id
LEFT JOIN affiliate_cycle ac ON udp.user_id = ac.user_id
WHERE udp.date = '2025-07-15'
ORDER BY udp.daily_profit DESC;

-- 2. この5名の運用開始日確認
SELECT 
    '=== 運用開始日確認 ===' as investigation,
    udp.user_id,
    u.email,
    MIN(p.admin_approved_at) as first_approval,
    MIN(p.admin_approved_at)::date + 15 as operation_start_date,
    CASE 
        WHEN MIN(p.admin_approved_at)::date + 15 <= '2025-07-15' THEN '運用中'
        ELSE '運用前'
    END as status_on_715,
    udp.daily_profit
FROM user_daily_profit udp
JOIN users u ON udp.user_id = u.user_id
LEFT JOIN purchases p ON udp.user_id = p.user_id AND p.admin_approved = true
WHERE udp.date = '2025-07-15'
GROUP BY udp.user_id, u.email, udp.daily_profit
ORDER BY MIN(p.admin_approved_at);

-- 3. 利益作成時間の分析
SELECT 
    '=== 作成時間分析 ===' as investigation,
    user_id,
    daily_profit,
    created_at,
    DATE_TRUNC('minute', created_at) as batch_time
FROM user_daily_profit
WHERE date = '2025-07-15'
ORDER BY created_at;