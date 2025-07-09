-- Simple check for user 7A9637 referral tree
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

-- Simple query to check 7A9637's referral tree levels
SELECT 
    'Level 1' as level,
    COUNT(*) as count,
    STRING_AGG(user_id, ', ') as user_ids
FROM users 
WHERE referrer_user_id = '7A9637'

UNION ALL

SELECT 
    'Level 2' as level,
    COUNT(*) as count,
    STRING_AGG(u2.user_id, ', ') as user_ids
FROM users u1
JOIN users u2 ON u2.referrer_user_id = u1.user_id
WHERE u1.referrer_user_id = '7A9637'

UNION ALL

SELECT 
    'Level 3' as level,
    COUNT(*) as count,
    STRING_AGG(u3.user_id, ', ') as user_ids
FROM users u1
JOIN users u2 ON u2.referrer_user_id = u1.user_id
JOIN users u3 ON u3.referrer_user_id = u2.user_id
WHERE u1.referrer_user_id = '7A9637'

UNION ALL

SELECT 
    'Level 4' as level,
    COUNT(*) as count,
    STRING_AGG(u4.user_id, ', ') as user_ids
FROM users u1
JOIN users u2 ON u2.referrer_user_id = u1.user_id
JOIN users u3 ON u3.referrer_user_id = u2.user_id
JOIN users u4 ON u4.referrer_user_id = u3.user_id
WHERE u1.referrer_user_id = '7A9637'

ORDER BY level;

-- Use the existing referral tree function
SELECT 
    'Referral Tree Function Result' as check_type,
    level_num,
    COUNT(*) as count,
    STRING_AGG(user_id, ', ') as user_ids
FROM get_referral_tree('7A9637')
GROUP BY level_num
ORDER BY level_num;
