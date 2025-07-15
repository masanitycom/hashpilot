-- Query 1: Check purchases table for users Y9FVT1 and 7A9637
\echo '=== PURCHASES TABLE CHECK ==='
SELECT 
    user_id,
    amount_usd,
    admin_approved,
    admin_approved_at,
    CASE 
        WHEN admin_approved_at IS NOT NULL 
        THEN admin_approved_at + INTERVAL '15 days'
        ELSE NULL 
    END as operation_start_date,
    CASE 
        WHEN admin_approved_at IS NOT NULL AND (admin_approved_at + INTERVAL '15 days') <= CURRENT_DATE
        THEN 'Started'
        WHEN admin_approved_at IS NOT NULL
        THEN 'Waiting'
        ELSE 'Not Approved'
    END as operation_status,
    created_at
FROM purchases 
WHERE user_id IN ('Y9FVT1', '7A9637')
ORDER BY created_at;

\echo ''
\echo '=== DAILY PROFIT RECORDS CHECK ==='
-- Query 2: Check if they have daily profit records
SELECT 
    user_id,
    COUNT(*) as profit_days,
    SUM(daily_profit) as total_profit,
    MIN(date) as first_profit_date,
    MAX(date) as latest_profit_date
FROM user_daily_profit 
WHERE user_id IN ('Y9FVT1', '7A9637')
GROUP BY user_id;

\echo ''
\echo '=== AFFILIATE CYCLE STATUS CHECK ==='
-- Query 3: Check affiliate cycle status
SELECT 
    user_id,
    total_nft_count,
    available_usdt,
    phase,
    updated_at
FROM affiliate_cycle 
WHERE user_id IN ('Y9FVT1', '7A9637');

\echo ''
\echo '=== ALL PURCHASES FOR THESE USERS ==='
-- Additional check to see all purchase data
SELECT 
    user_id,
    nft_quantity,
    amount_usd,
    payment_status,
    admin_approved,
    admin_approved_at,
    is_auto_purchase,
    created_at
FROM purchases 
WHERE user_id IN ('Y9FVT1', '7A9637')
ORDER BY user_id, created_at;