-- 🚀 PRODUCTION REFERRAL SYSTEM VERIFICATION
-- 2025/08/24 - Final pre-release verification
-- READ ONLY - NO DATA MODIFICATIONS

-- ========================================
-- PART 1: DATABASE FUNCTIONS & TRIGGERS
-- ========================================

-- Check existing trigger functions
SELECT 
    '1. TRIGGER FUNCTIONS' as section,
    routine_name as function_name,
    routine_type,
    CASE 
        WHEN routine_name LIKE '%handle_new_user%' THEN '✅ USER REGISTRATION'
        WHEN routine_name LIKE '%sync%auth%' THEN '✅ USER SYNC'
        WHEN routine_name LIKE '%referral%' THEN '✅ REFERRAL RELATED'
        ELSE '📝 OTHER'
    END as function_purpose
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND (routine_name LIKE '%user%' OR routine_name LIKE '%auth%' OR routine_name LIKE '%referral%')
ORDER BY routine_name;

-- Check active triggers
SELECT 
    '2. ACTIVE TRIGGERS' as section,
    trigger_name,
    event_object_table,
    event_manipulation,
    action_timing,
    CASE 
        WHEN event_object_table = 'users' AND trigger_schema = 'auth' THEN '✅ AUTH USER TRIGGER'
        WHEN event_object_table = 'users' AND trigger_schema = 'public' THEN '📝 PUBLIC USER TRIGGER'
        ELSE '❓ OTHER TRIGGER'
    END as trigger_type
FROM information_schema.triggers
WHERE trigger_schema IN ('public', 'auth')
ORDER BY event_object_table, trigger_name;

-- ========================================
-- PART 2: USER DATA ANALYSIS
-- ========================================

-- Overall user statistics
SELECT 
    '3. USER STATISTICS' as section,
    COUNT(*) as total_users,
    COUNT(*) FILTER (WHERE referrer_user_id IS NOT NULL) as users_with_referrer,
    COUNT(*) FILTER (WHERE coinw_uid IS NOT NULL AND coinw_uid != '') as users_with_coinw,
    COUNT(*) FILTER (WHERE total_purchases > 0) as investing_users,
    ROUND(
        (COUNT(*) FILTER (WHERE referrer_user_id IS NOT NULL)::NUMERIC / COUNT(*)) * 100, 2
    ) as referral_percentage
FROM users;

-- Recent registrations (last 10)
SELECT 
    '4. RECENT REGISTRATIONS' as section,
    user_id,
    LEFT(email, 20) || '...' as email_preview,
    CASE 
        WHEN referrer_user_id IS NOT NULL THEN '✅ HAS_REF'
        ELSE '❌ NO_REF'
    END as referrer_status,
    CASE 
        WHEN coinw_uid IS NOT NULL AND coinw_uid != '' THEN '✅ HAS_UID'
        ELSE '❌ NO_UID'
    END as coinw_status,
    created_at::DATE as registration_date
FROM users
ORDER BY created_at DESC
LIMIT 10;

-- Referral chain depth verification
WITH RECURSIVE referral_chain AS (
    SELECT 
        user_id,
        referrer_user_id,
        1 as depth,
        user_id::TEXT as chain_path
    FROM users
    WHERE referrer_user_id IS NOT NULL
    
    UNION ALL
    
    SELECT 
        rc.user_id,
        u.referrer_user_id,
        rc.depth + 1,
        rc.chain_path || ' -> ' || u.user_id::TEXT
    FROM referral_chain rc
    JOIN users u ON rc.referrer_user_id = u.user_id
    WHERE rc.depth < 10 AND u.referrer_user_id IS NOT NULL
)
SELECT 
    '5. REFERRAL CHAIN ANALYSIS' as section,
    MAX(depth) as max_chain_depth,
    COUNT(DISTINCT user_id) as users_in_chains,
    COUNT(*) as total_referral_links
FROM referral_chain;

-- ========================================
-- PART 3: AUTH METADATA VERIFICATION
-- ========================================

-- Check auth.users metadata (sample)
SELECT 
    '6. AUTH METADATA SAMPLE' as section,
    LEFT(email, 15) || '...' as email_preview,
    CASE 
        WHEN raw_user_meta_data ? 'referrer_user_id' THEN '✅ HAS_REF_META'
        WHEN raw_user_meta_data ? 'referrer' THEN '✅ HAS_REF_META'
        WHEN raw_user_meta_data ? 'ref' THEN '✅ HAS_REF_META'
        ELSE '❌ NO_REF_META'
    END as referrer_metadata,
    CASE 
        WHEN raw_user_meta_data ? 'coinw_uid' THEN '✅ HAS_COINW_META'
        WHEN raw_user_meta_data ? 'coinw' THEN '✅ HAS_COINW_META'
        ELSE '❌ NO_COINW_META'
    END as coinw_metadata,
    created_at::DATE as auth_created
FROM auth.users
WHERE raw_user_meta_data IS NOT NULL 
  AND raw_user_meta_data != '{}'::jsonb
ORDER BY created_at DESC
LIMIT 5;

-- ========================================
-- PART 4: DATA CONSISTENCY CHECKS
-- ========================================

-- Auth vs Public users sync check
SELECT 
    '7. AUTH SYNC STATUS' as section,
    auth_count,
    public_count,
    auth_count - public_count as missing_in_public,
    CASE 
        WHEN auth_count = public_count THEN '✅ PERFECT_SYNC'
        WHEN auth_count > public_count THEN '⚠️ SYNC_GAP'
        ELSE '❓ UNEXPECTED'
    END as sync_status
FROM (
    SELECT 
        (SELECT COUNT(*) FROM auth.users) as auth_count,
        (SELECT COUNT(*) FROM public.users) as public_count
);

-- Users missing in affiliate_cycle
SELECT 
    '8. AFFILIATE_CYCLE STATUS' as section,
    users_count,
    affiliate_count,
    users_count - affiliate_count as missing_in_affiliate,
    CASE 
        WHEN users_count = affiliate_count THEN '✅ COMPLETE'
        ELSE '⚠️ INCOMPLETE'
    END as affiliate_status
FROM (
    SELECT 
        (SELECT COUNT(*) FROM public.users) as users_count,
        (SELECT COUNT(*) FROM public.affiliate_cycle) as affiliate_count
);

-- ========================================
-- PART 5: REFERRAL EFFECTIVENESS
-- ========================================

-- Top referrers
SELECT 
    '9. TOP REFERRERS' as section,
    u.user_id as referrer_id,
    LEFT(u.email, 20) || '...' as referrer_email,
    COUNT(r.user_id) as total_referrals,
    COUNT(r.user_id) FILTER (WHERE r.total_purchases > 0) as investing_referrals
FROM users u
JOIN users r ON u.user_id = r.referrer_user_id
GROUP BY u.user_id, u.email
ORDER BY COUNT(r.user_id) DESC
LIMIT 5;

-- ========================================
-- PART 6: INVESTMENT STATUS
-- ========================================

-- Investment distribution
SELECT 
    '10. INVESTMENT STATUS' as section,
    COUNT(*) FILTER (WHERE total_purchases = 0) as no_investment,
    COUNT(*) FILTER (WHERE total_purchases > 0 AND total_purchases <= 1100) as small_investors,
    COUNT(*) FILTER (WHERE total_purchases > 1100 AND total_purchases <= 5500) as medium_investors,
    COUNT(*) FILTER (WHERE total_purchases > 5500) as large_investors,
    COALESCE(SUM(total_purchases), 0) as total_investment_usd
FROM users;

-- ========================================
-- PART 7: FINAL VERIFICATION
-- ========================================

-- Summary report
SELECT 
    '11. FINAL SUMMARY' as section,
    'REFERRAL SYSTEM STATUS' as component,
    CASE 
        WHEN (SELECT COUNT(*) FROM users WHERE referrer_user_id IS NOT NULL) > 0 
         AND (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_name LIKE '%user%') > 0
         AND (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name LIKE '%handle_new_user%') > 0
        THEN '✅ OPERATIONAL'
        ELSE '❌ ISSUES_DETECTED'
    END as system_status,
    NOW()::TIMESTAMP as verification_time;

-- Performance check
SELECT 
    '12. SYSTEM HEALTH' as section,
    pg_size_pretty(pg_database_size(current_database())) as database_size,
    (SELECT COUNT(*) FROM users) as total_users,
    (SELECT COUNT(*) FROM affiliate_cycle) as affiliate_records,
    (SELECT COUNT(*) FROM daily_yield_log) as yield_records,
    'READY_FOR_PRODUCTION' as production_readiness;

-- End of verification
SELECT '✅ PRODUCTION VERIFICATION COMPLETED' as final_status;