-- Database Connection and Data Verification
-- Check if I'm connected to the right Supabase database
-- User reports seeing data for user 7A9637 but queries return empty

-- Basic table existence and row counts
\echo '=== BASIC TABLE COUNTS ==='
SELECT 'users' as table_name, COUNT(*) as total_count FROM users
UNION ALL
SELECT 'purchases', COUNT(*) FROM purchases  
UNION ALL
SELECT 'user_daily_profit', COUNT(*) FROM user_daily_profit
UNION ALL
SELECT 'affiliate_cycle', COUNT(*) FROM affiliate_cycle
UNION ALL
SELECT 'withdrawal_requests', COUNT(*) FROM withdrawal_requests
UNION ALL
SELECT 'admins', COUNT(*) FROM admins;

\echo '=== SPECIFIC USER 7A9637 CHECK ==='
-- Check if specific user 7A9637 exists
SELECT * FROM users WHERE user_id = '7A9637' LIMIT 1;

\echo '=== SIMILAR USER IDs ==='
-- Check for users with similar IDs
SELECT user_id, email, full_name, total_purchases, is_active, created_at 
FROM users 
WHERE user_id LIKE '%7A9637%' OR user_id LIKE '%7A%' OR user_id LIKE '%9637%'
ORDER BY created_at DESC;

\echo '=== RECENT DAILY PROFITS ==='
-- Check recent daily profit entries
SELECT user_id, date, daily_profit, yield_rate, user_rate, base_amount, phase, created_at
FROM user_daily_profit 
ORDER BY created_at DESC 
LIMIT 10;

\echo '=== RECENT PURCHASES ==='
-- Check recent purchases
SELECT user_id, nft_quantity, amount_usd, payment_status, admin_approved, created_at
FROM purchases 
ORDER BY created_at DESC 
LIMIT 10;

\echo '=== RECENT CYCLE DATA ==='
-- Check affiliate cycle data
SELECT user_id, phase, total_nft_count, cum_usdt, available_usdt, cycle_number, next_action
FROM affiliate_cycle 
ORDER BY updated_at DESC 
LIMIT 10;

\echo '=== ADMIN USERS ==='
-- Check admin users
SELECT user_id, role, created_at FROM admins ORDER BY created_at;

\echo '=== RECENT SYSTEM LOGS ==='
-- Check recent system logs for activity
SELECT log_type, operation, user_id, message, created_at
FROM system_logs 
ORDER BY created_at DESC 
LIMIT 5;

\echo '=== DATABASE INFO ==='
-- Check current database info
SELECT current_database(), current_user, inet_server_addr(), inet_server_port();