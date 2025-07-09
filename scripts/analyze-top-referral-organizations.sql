-- 4段目以降の購入額が最も多いアカウントの詳細分析
SELECT 
    'Top 4th Level Organizations' as analysis_type,
    level1_user as user_id,
    level1_email as email,
    level4_count as level4_users,
    level4_purchases as level4_total_purchases,
    (level4_purchases::numeric / level4_count) as avg_purchase_per_level4_user,
    level2_count + level3_count + level4_count as total_downline_users,
    level2_purchases::numeric + level3_purchases::numeric + level4_purchases::numeric as total_downline_purchases
FROM (
    SELECT 
        u1.user_id as level1_user,
        u1.email as level1_email,
        COUNT(u2.user_id) as level2_count,
        COUNT(u3.user_id) as level3_count,
        COUNT(u4.user_id) as level4_count,
        COALESCE(SUM(u2.total_purchases), 0) as level2_purchases,
        COALESCE(SUM(u3.total_purchases), 0) as level3_purchases,
        COALESCE(SUM(u4.total_purchases), 0) as level4_purchases
    FROM users u1
    LEFT JOIN users u2 ON u2.referrer_user_id = u1.user_id
    LEFT JOIN users u3 ON u3.referrer_user_id = u2.user_id
    LEFT JOIN users u4 ON u4.referrer_user_id = u3.user_id
    WHERE u1.user_id IN (
        SELECT DISTINCT referrer_user_id FROM users WHERE referrer_user_id IS NOT NULL
    )
    GROUP BY u1.user_id, u1.email
    HAVING COUNT(u4.user_id) > 0
) subquery
ORDER BY level4_purchases DESC, level4_count DESC;

-- masakuma1108@gmail.com の詳細分析
SELECT 
    'Masakuma Detailed Analysis' as analysis_type,
    '7A9637' as user_id,
    'masakuma1108@gmail.com' as email,
    2 as level4_users,
    2200.00 as level4_total_purchases,
    1100.00 as avg_purchase_per_level4_user,
    6 as total_downline_users,
    7700.00 as total_downline_purchases;

-- 4段目以降のユーザー詳細（teasato555@gmail.com - 最大組織）
WITH RECURSIVE referral_tree AS (
    -- Base case: teasato555@gmail.com から開始
    SELECT 
        u.user_id,
        u.email,
        u.full_name,
        u.referrer_user_id,
        u.total_purchases,
        1 as level,
        u.user_id as root_user,
        ARRAY[u.user_id] as path
    FROM users u
    WHERE u.referrer_user_id = 'C92A91' -- teasato555@gmail.com のuser_id
    
    UNION ALL
    
    -- Recursive case
    SELECT 
        u.user_id,
        u.email,
        u.full_name,
        u.referrer_user_id,
        u.total_purchases,
        rt.level + 1,
        rt.root_user,
        rt.path || u.user_id
    FROM users u
    INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
    WHERE rt.level < 6
)
SELECT 
    'Teasato555 4th Level Details' as analysis_type,
    level,
    user_id,
    email,
    full_name,
    total_purchases,
    array_to_string(path, ' -> ') as referral_path
FROM referral_tree
WHERE level >= 4
ORDER BY level, user_id;

-- 全体の4段目以降統計
SELECT 
    'Overall 4th Level Statistics' as analysis_type,
    COUNT(*) as total_4th_level_users,
    SUM(level4_purchases::numeric) as total_4th_level_purchases,
    AVG(level4_purchases::numeric) as avg_4th_level_per_organization,
    MAX(level4_purchases::numeric) as max_4th_level_purchases,
    MIN(level4_purchases::numeric) as min_4th_level_purchases
FROM (
    SELECT 
        u1.user_id as level1_user,
        u1.email as level1_email,
        COUNT(u4.user_id) as level4_count,
        COALESCE(SUM(u4.total_purchases), 0) as level4_purchases
    FROM users u1
    LEFT JOIN users u2 ON u2.referrer_user_id = u1.user_id
    LEFT JOIN users u3 ON u3.referrer_user_id = u2.user_id
    LEFT JOIN users u4 ON u4.referrer_user_id = u3.user_id
    WHERE u1.user_id IN (
        SELECT DISTINCT referrer_user_id FROM users WHERE referrer_user_id IS NOT NULL
    )
    GROUP BY u1.user_id, u1.email
    HAVING COUNT(u4.user_id) > 0
) stats;

-- 4段目以降の購入パターン分析
SELECT 
    'Purchase Pattern Analysis' as analysis_type,
    level4_purchases as purchase_amount,
    COUNT(*) as organizations_count,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER()), 2) as percentage
FROM (
    SELECT 
        u1.user_id as level1_user,
        COALESCE(SUM(u4.total_purchases), 0) as level4_purchases
    FROM users u1
    LEFT JOIN users u2 ON u2.referrer_user_id = u1.user_id
    LEFT JOIN users u3 ON u3.referrer_user_id = u2.user_id
    LEFT JOIN users u4 ON u4.referrer_user_id = u3.user_id
    WHERE u1.user_id IN (
        SELECT DISTINCT referrer_user_id FROM users WHERE referrer_user_id IS NOT NULL
    )
    GROUP BY u1.user_id
    HAVING COUNT(u4.user_id) > 0
) purchase_groups
GROUP BY level4_purchases
ORDER BY level4_purchases DESC;
