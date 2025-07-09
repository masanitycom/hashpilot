-- Check if 4th level and beyond calculations are working correctly
SELECT 
    'Referral Tree 4th Level Check' as check_type,
    level_num,
    COUNT(*) as user_count,
    SUM(personal_purchases) as total_purchases,
    AVG(personal_purchases) as avg_purchases
FROM get_referral_tree('2BF53B')
WHERE level_num >= 4
GROUP BY level_num
ORDER BY level_num;

-- Check the total count for levels 4+
SELECT 
    'Level 4+ Summary' as check_type,
    COUNT(*) as total_users_4plus,
    SUM(personal_purchases) as total_purchases_4plus
FROM get_referral_tree('2BF53B')
WHERE level_num >= 4;

-- Test with another user to verify the function works
SELECT 
    'Test Another User' as check_type,
    level_num,
    COUNT(*) as user_count
FROM get_referral_tree('V1SPIY')
GROUP BY level_num
ORDER BY level_num;

-- Check all users and their referral levels
SELECT 
    'All Users Referral Levels' as check_type,
    u.user_id,
    u.email,
    u.referrer_user_id,
    CASE 
        WHEN u.referrer_user_id IS NULL THEN 0
        ELSE 1
    END as has_referrer
FROM users u
ORDER BY u.created_at DESC
LIMIT 20;

-- Check if there are any deep referral chains
WITH RECURSIVE referral_chain AS (
    -- Base case: users without referrers (level 0)
    SELECT 
        user_id,
        email,
        referrer_user_id,
        0 as level,
        ARRAY[user_id] as chain
    FROM users 
    WHERE referrer_user_id IS NULL
    
    UNION ALL
    
    -- Recursive case: users with referrers
    SELECT 
        u.user_id,
        u.email,
        u.referrer_user_id,
        rc.level + 1,
        rc.chain || u.user_id
    FROM users u
    INNER JOIN referral_chain rc ON u.referrer_user_id = rc.user_id
    WHERE rc.level < 10 -- Prevent infinite recursion
)
SELECT 
    'Referral Chain Analysis' as check_type,
    level,
    COUNT(*) as user_count,
    MAX(array_length(chain, 1)) as max_chain_length
FROM referral_chain
GROUP BY level
ORDER BY level;
