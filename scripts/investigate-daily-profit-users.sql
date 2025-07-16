-- 現在日利が発生しているユーザーの調査
-- 2025-01-16 実行

\echo '=== 最新の日利記録確認 ==='
-- 最新の日利記録を確認
SELECT 
    date,
    COUNT(*) as user_count,
    SUM(daily_profit) as total_daily_profit,
    AVG(daily_profit) as avg_daily_profit,
    MIN(daily_profit) as min_daily_profit,
    MAX(daily_profit) as max_daily_profit
FROM user_daily_profit 
WHERE date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY date
ORDER BY date DESC;

\echo '=== 本日の日利受取ユーザー一覧 ==='
-- 本日の日利受取ユーザー
SELECT 
    udp.user_id,
    u.email,
    u.full_name,
    udp.daily_profit,
    udp.yield_rate,
    udp.user_rate,
    udp.base_amount,
    udp.phase,
    u.total_purchases,
    u.has_approved_nft
FROM user_daily_profit udp
JOIN users u ON udp.user_id = u.user_id
WHERE udp.date = CURRENT_DATE
ORDER BY udp.daily_profit DESC
LIMIT 20;

\echo '=== 昨日の日利受取ユーザー一覧 ==='
-- 昨日の日利受取ユーザー
SELECT 
    udp.user_id,
    u.email,
    u.full_name,
    udp.daily_profit,
    udp.yield_rate,
    udp.user_rate,
    udp.base_amount,
    udp.phase,
    u.total_purchases,
    u.has_approved_nft
FROM user_daily_profit udp
JOIN users u ON udp.user_id = u.user_id
WHERE udp.date = CURRENT_DATE - INTERVAL '1 day'
ORDER BY udp.daily_profit DESC
LIMIT 20;

\echo '=== ユーザー別累積日利トップ20 ==='
-- ユーザー別累積日利（過去30日間）
SELECT 
    udp.user_id,
    u.email,
    u.full_name,
    COUNT(*) as profit_days,
    SUM(udp.daily_profit) as total_profit_30days,
    AVG(udp.daily_profit) as avg_daily_profit,
    MAX(udp.daily_profit) as max_daily_profit,
    MIN(udp.date) as first_profit_date,
    MAX(udp.date) as last_profit_date,
    u.total_purchases,
    u.has_approved_nft
FROM user_daily_profit udp
JOIN users u ON udp.user_id = u.user_id
WHERE udp.date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY udp.user_id, u.email, u.full_name, u.total_purchases, u.has_approved_nft
ORDER BY total_profit_30days DESC
LIMIT 20;

\echo '=== NFT購入状況と運用開始日 ==='
-- NFT購入状況と運用開始日
SELECT 
    p.user_id,
    u.email,
    u.full_name,
    COUNT(p.id) as nft_purchase_count,
    SUM(p.nft_quantity) as total_nft_quantity,
    SUM(p.amount_usd) as total_investment_usd,
    MIN(p.created_at) as first_purchase_date,
    MAX(p.created_at) as last_purchase_date,
    -- 運用開始日（承認から15日後）
    MIN(p.created_at + INTERVAL '15 days') as operation_start_date,
    CASE 
        WHEN MIN(p.created_at + INTERVAL '15 days') <= CURRENT_DATE THEN 'ACTIVE'
        ELSE 'WAITING'
    END as operation_status,
    u.has_approved_nft
FROM purchases p
JOIN users u ON p.user_id = u.user_id
WHERE p.admin_approved = true
GROUP BY p.user_id, u.email, u.full_name, u.has_approved_nft
ORDER BY total_investment_usd DESC
LIMIT 20;

\echo '=== アフィリエイトサイクル状況 ==='
-- アフィリエイトサイクル状況
SELECT 
    ac.user_id,
    u.email,
    u.full_name,
    ac.phase,
    ac.total_nft_count,
    ac.cum_usdt,
    ac.available_usdt,
    ac.auto_nft_count,
    ac.manual_nft_count,
    ac.cycle_number,
    ac.next_action,
    ac.cycle_start_date,
    u.has_approved_nft
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE ac.total_nft_count > 0
ORDER BY ac.cum_usdt DESC
LIMIT 20;

\echo '=== 日利設定ログ最新情報 ==='
-- 最新の日利設定情報
SELECT 
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    created_at
FROM daily_yield_log
ORDER BY date DESC
LIMIT 10;

\echo '=== システム統計サマリー ==='
-- システム統計サマリー
SELECT 
    'Total Users' as metric,
    COUNT(*) as value
FROM users
WHERE is_active = true

UNION ALL

SELECT 
    'Users with Approved NFT' as metric,
    COUNT(*) as value
FROM users
WHERE has_approved_nft = true

UNION ALL

SELECT 
    'Total NFT Purchases' as metric,
    COUNT(*) as value
FROM purchases
WHERE admin_approved = true

UNION ALL

SELECT 
    'Users with Daily Profit (Last 7 days)' as metric,
    COUNT(DISTINCT user_id) as value
FROM user_daily_profit
WHERE date >= CURRENT_DATE - INTERVAL '7 days'

UNION ALL

SELECT 
    'Total Daily Profit (Last 7 days)' as metric,
    ROUND(SUM(daily_profit), 2) as value
FROM user_daily_profit
WHERE date >= CURRENT_DATE - INTERVAL '7 days'

UNION ALL

SELECT 
    'Users in Affiliate Cycle' as metric,
    COUNT(*) as value
FROM affiliate_cycle
WHERE total_nft_count > 0;

\echo '=== 日利発生の運用開始条件チェック ==='
-- 運用開始条件を満たしているユーザー
SELECT 
    p.user_id,
    u.email,
    u.full_name,
    MIN(p.created_at) as first_purchase_date,
    MIN(p.created_at + INTERVAL '15 days') as operation_start_date,
    CURRENT_DATE - MIN(p.created_at + INTERVAL '15 days') as days_since_operation_start,
    SUM(p.nft_quantity) as total_nft_quantity,
    SUM(p.amount_usd) as total_investment_usd,
    CASE 
        WHEN MIN(p.created_at + INTERVAL '15 days') <= CURRENT_DATE THEN 'SHOULD_RECEIVE_PROFIT'
        ELSE 'WAITING_FOR_OPERATION_START'
    END as profit_eligibility,
    -- 実際に日利を受け取っているかチェック
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM user_daily_profit udp 
            WHERE udp.user_id = p.user_id 
            AND udp.date >= CURRENT_DATE - INTERVAL '7 days'
        ) THEN 'RECEIVING_PROFIT'
        ELSE 'NOT_RECEIVING_PROFIT'
    END as actual_profit_status
FROM purchases p
JOIN users u ON p.user_id = u.user_id
WHERE p.admin_approved = true
GROUP BY p.user_id, u.email, u.full_name
HAVING MIN(p.created_at + INTERVAL '15 days') <= CURRENT_DATE
ORDER BY days_since_operation_start DESC;