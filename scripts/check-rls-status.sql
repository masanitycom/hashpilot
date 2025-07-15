-- Check Row Level Security (RLS) Status
-- This might explain why queries return empty results

\echo '=== RLS STATUS CHECK ==='
-- Check if RLS is enabled on key tables
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled,
    hasoids
FROM pg_tables 
WHERE tablename IN ('users', 'purchases', 'user_daily_profit', 'affiliate_cycle', 'withdrawal_requests', 'admins', 'system_logs')
ORDER BY tablename;

\echo '=== RLS POLICIES ==='
-- Check RLS policies that might be blocking access
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename IN ('users', 'purchases', 'user_daily_profit', 'affiliate_cycle', 'withdrawal_requests', 'admins', 'system_logs')
ORDER BY tablename, policyname;

\echo '=== CURRENT SESSION INFO ==='
-- Check what role/user we're running as
SELECT 
    current_user,
    session_user,
    current_role,
    current_setting('role') as current_role_setting;

\echo '=== AUTH CONTEXT ==='
-- Check if there's any auth context set
SELECT 
    current_setting('request.jwt.claims', true) as jwt_claims,
    current_setting('request.jwt.claim.sub', true) as jwt_sub,
    current_setting('request.jwt.claim.role', true) as jwt_role;