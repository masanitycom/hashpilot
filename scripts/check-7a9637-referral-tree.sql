-- Check referral tree for user 7A9637 specifically
SELECT 
    'User 7A9637 Referral Tree Analysis' as analysis_type,
    level_num,
    COUNT(*) as user_count,
    SUM(personal_purchases) as total_purchases,
    AVG(personal_purchases) as avg_purchases,
    STRING_AGG(user_id, ', ' ORDER BY user_id) as user_ids
FROM get_referral_tree('7A9637')
GROUP BY level_num
ORDER BY level_num;

-- Check if 7A9637 exists and has referrals
SELECT 
    'User 7A9637 Basic Info' as check_type,
    user_id,
    email,
    referrer_user_id,
    has_approved_nft,
    total_purchases,
    created_at
FROM users 
WHERE user_id = '7A9637';

-- Check direct referrals of 7A9637
SELECT 
    'Direct Referrals of 7A9637' as check_type,
    user_id,
    email,
    referrer_user_id,
    has_approved_nft,
    total_purchases,
    created_at
FROM users 
WHERE referrer_user_id = '7A9637'
ORDER BY created_at;

-- Check the referral tree function directly
SELECT 
    'Raw Function Output for 7A9637' as check_type,
    *
FROM get_referral_tree('7A9637')
ORDER BY level_num, user_id;

-- Check if there are any users with 4+ levels in the entire system
SELECT 
    'System Wide 4+ Level Check' as check_type,
    COUNT(*) as total_4plus_users
FROM get_referral_tree('2BF53B') -- Using a known active user
WHERE level_num >= 4;

-- Verify the referral tree function is working correctly
SELECT 
    'Function Test with Known User' as check_type,
    level_num,
    COUNT(*) as count
FROM get_referral_tree('2BF53B')
GROUP BY level_num
ORDER BY level_num;

-- Simple check for 4th level users under 7A9637 using manual joins
SELECT 
    'Manual 4th Level Check for 7A9637' as check_type,
    COUNT(*) as fourth_level_count,
    STRING_AGG(u4.user_id, ', ') as fourth_level_users
FROM users u1
JOIN users u2 ON u2.referrer_user_id = u1.user_id
JOIN users u3 ON u3.referrer_user_id = u2.user_id
JOIN users u4 ON u4.referrer_user_id = u3.user_id
WHERE u1.user_id = '7A9637';

-- Check all levels manually for 7A9637
SELECT 
    'Level 1 (Direct) for 7A9637' as level_type,
    COUNT(*) as user_count,
    STRING_AGG(user_id, ', ') as users
FROM users 
WHERE referrer_user_id = '7A9637';

SELECT 
    'Level 2 for 7A9637' as level_type,
    COUNT(*) as user_count,
    STRING_AGG(u2.user_id, ', ') as users
FROM users u1
JOIN users u2 ON u2.referrer_user_id = u1.user_id
WHERE u1.referrer_user_id = '7A9637';

SELECT 
    'Level 3 for 7A9637' as level_type,
    COUNT(*) as user_count,
    STRING_AGG(u3.user_id, ', ') as users
FROM users u1
JOIN users u2 ON u2.referrer_user_id = u1.user_id
JOIN users u3 ON u3.referrer_user_id = u2.user_id
WHERE u1.referrer_user_id = '7A9637';

SELECT 
    'Level 4 for 7A9637' as level_type,
    COUNT(*) as user_count,
    STRING_AGG(u4.user_id, ', ') as users
FROM users u1
JOIN users u2 ON u2.referrer_user_id = u1.user_id
JOIN users u3 ON u3.referrer_user_id = u2.user_id
JOIN users u4 ON u4.referrer_user_id = u3.user_id
WHERE u1.referrer_user_id = '7A9637';
