-- 緊急調査: 日利発生状況の詳細調査
-- RLSの制限を考慮した複数アプローチでのデータ取得

-- 1. ユーザー「7A9637」の詳細調査
SELECT 
    'USER_7A9637_BASIC_INFO' as query_type,
    u.user_id,
    u.email,
    u.full_name,
    u.total_purchases,
    u.is_active,
    u.has_approved_nft,
    u.created_at
FROM users u 
WHERE u.user_id = '7A9637';

-- 2. ユーザー「7A9637」の日利記録
SELECT 
    'USER_7A9637_DAILY_PROFIT' as query_type,
    udp.user_id,
    udp.date,
    udp.daily_profit,
    udp.yield_rate,
    udp.user_rate,
    udp.base_amount,
    udp.phase,
    udp.created_at
FROM user_daily_profit udp
WHERE udp.user_id = '7A9637'
ORDER BY udp.date DESC;

-- 3. ユーザー「7A9637」のNFT購入状況
SELECT 
    'USER_7A9637_PURCHASES' as query_type,
    p.user_id,
    p.nft_quantity,
    p.amount_usd,
    p.payment_status,
    p.admin_approved,
    p.is_auto_purchase,
    p.created_at
FROM purchases p
WHERE p.user_id = '7A9637'
ORDER BY p.created_at DESC;

-- 4. ユーザー「7A9637」のサイクル状況
SELECT 
    'USER_7A9637_CYCLE' as query_type,
    ac.user_id,
    ac.phase,
    ac.total_nft_count,
    ac.cum_usdt,
    ac.available_usdt,
    ac.auto_nft_count,
    ac.manual_nft_count,
    ac.cycle_number,
    ac.next_action,
    ac.updated_at
FROM affiliate_cycle ac
WHERE ac.user_id = '7A9637';

-- 5. ユーザー「2BF53B」の詳細調査
SELECT 
    'USER_2BF53B_BASIC_INFO' as query_type,
    u.user_id,
    u.email,
    u.full_name,
    u.total_purchases,
    u.is_active,
    u.has_approved_nft,
    u.created_at
FROM users u 
WHERE u.user_id = '2BF53B';

-- 6. ユーザー「2BF53B」の日利記録
SELECT 
    'USER_2BF53B_DAILY_PROFIT' as query_type,
    udp.user_id,
    udp.date,
    udp.daily_profit,
    udp.yield_rate,
    udp.user_rate,
    udp.base_amount,
    udp.phase,
    udp.created_at
FROM user_daily_profit udp
WHERE udp.user_id = '2BF53B'
ORDER BY udp.date DESC;

-- 7. ユーザー「2BF53B」のNFT購入状況
SELECT 
    'USER_2BF53B_PURCHASES' as query_type,
    p.user_id,
    p.nft_quantity,
    p.amount_usd,
    p.payment_status,
    p.admin_approved,
    p.is_auto_purchase,
    p.created_at
FROM purchases p
WHERE p.user_id = '2BF53B'
ORDER BY p.created_at DESC;

-- 8. ユーザー「2BF53B」のサイクル状況
SELECT 
    'USER_2BF53B_CYCLE' as query_type,
    ac.user_id,
    ac.phase,
    ac.total_nft_count,
    ac.cum_usdt,
    ac.available_usdt,
    ac.auto_nft_count,
    ac.manual_nft_count,
    ac.cycle_number,
    ac.next_action,
    ac.updated_at
FROM affiliate_cycle ac
WHERE ac.user_id = '2BF53B';

-- 9. 全体の運用開始ユーザー一覧（has_approved_nft = true）
SELECT 
    'ALL_APPROVED_USERS' as query_type,
    u.user_id,
    u.email,
    u.full_name,
    u.total_purchases,
    u.created_at,
    COUNT(p.id) as purchase_count,
    SUM(p.nft_quantity) as total_nft_quantity,
    SUM(p.amount_usd) as total_amount_usd
FROM users u
LEFT JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
WHERE u.has_approved_nft = true
GROUP BY u.user_id, u.email, u.full_name, u.total_purchases, u.created_at
ORDER BY u.created_at DESC;

-- 10. 最新の日利記録全体（最新10件）
SELECT 
    'LATEST_DAILY_PROFITS' as query_type,
    udp.user_id,
    udp.date,
    udp.daily_profit,
    udp.yield_rate,
    udp.user_rate,
    udp.base_amount,
    udp.phase,
    udp.created_at
FROM user_daily_profit udp
ORDER BY udp.date DESC, udp.created_at DESC
LIMIT 10;

-- 11. 最新の日利設定ログ
SELECT 
    'LATEST_YIELD_SETTINGS' as query_type,
    dyl.date,
    dyl.yield_rate,
    dyl.margin_rate,
    dyl.user_rate,
    dyl.is_month_end,
    dyl.created_at
FROM daily_yield_log dyl
ORDER BY dyl.date DESC
LIMIT 5;

-- 12. 運用開始条件チェック（15日経過）
SELECT 
    'OPERATION_START_CHECK' as query_type,
    p.user_id,
    p.created_at as purchase_date,
    p.created_at + INTERVAL '15 days' as operation_start_date,
    CURRENT_DATE as today,
    CASE 
        WHEN CURRENT_DATE >= p.created_at + INTERVAL '15 days' THEN 'STARTED'
        ELSE 'WAITING'
    END as operation_status,
    CURRENT_DATE - (p.created_at + INTERVAL '15 days') as days_since_start
FROM purchases p
WHERE p.admin_approved = true
ORDER BY p.created_at DESC;