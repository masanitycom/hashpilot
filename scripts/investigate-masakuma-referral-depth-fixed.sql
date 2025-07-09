-- masakuma1108@gmail.com のアカウント調査
SELECT 
    'Masakuma Account Info' as check_type,
    user_id,
    email,
    full_name,
    referrer_user_id,
    total_purchases,
    has_approved_nft,
    created_at
FROM users 
WHERE email = 'masakuma1108@gmail.com';

-- masakuma1108@gmail.com の紹介ツリーを調査（型修正版）
WITH RECURSIVE referral_tree AS (
    -- Base case: masakuma1108@gmail.com から開始
    SELECT 
        u.user_id,
        u.email,
        u.referrer_user_id,
        u.total_purchases,
        1 as level,
        ARRAY[u.user_id::text] as chain,
        u.user_id as root_user
    FROM users u
    WHERE u.referrer_user_id = (
        SELECT user_id FROM users WHERE email = 'masakuma1108@gmail.com'
    )
    
    UNION ALL
    
    -- Recursive case: 下位レベルを追加
    SELECT 
        u.user_id,
        u.email,
        u.referrer_user_id,
        u.total_purchases,
        rt.level + 1,
        rt.chain || u.user_id::text,
        rt.root_user
    FROM users u
    INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
    WHERE rt.level < 10 -- 最大10レベルまで
)
SELECT 
    'Masakuma Referral Tree' as check_type,
    level,
    COUNT(*) as user_count,
    COALESCE(SUM(total_purchases), 0) as level_total_purchases,
    COALESCE(AVG(total_purchases), 0) as avg_purchases_per_user,
    STRING_AGG(user_id, ', ') as user_ids
FROM referral_tree
GROUP BY level
ORDER BY level;

-- 全ユーザーの最大紹介深度を調査（簡略版）
WITH RECURSIVE all_referral_trees AS (
    -- Base case: 全ての直接紹介関係
    SELECT 
        u.user_id,
        u.email,
        u.referrer_user_id,
        u.total_purchases,
        1 as level,
        COALESCE(r.user_id, 'ROOT') as root_referrer,
        COALESCE(r.email, 'NO_REFERRER') as root_email
    FROM users u
    LEFT JOIN users r ON u.referrer_user_id = r.user_id
    WHERE u.referrer_user_id IS NOT NULL
    
    UNION ALL
    
    -- Recursive case: 下位レベル
    SELECT 
        u.user_id,
        u.email,
        u.referrer_user_id,
        u.total_purchases,
        art.level + 1,
        art.root_referrer,
        art.root_email
    FROM users u
    INNER JOIN all_referral_trees art ON u.referrer_user_id = art.user_id
    WHERE art.level < 10
),
max_depths AS (
    SELECT 
        root_referrer,
        root_email,
        MAX(level) as max_depth,
        COUNT(*) as total_referrals,
        COALESCE(SUM(total_purchases), 0) as total_referral_purchases
    FROM all_referral_trees
    GROUP BY root_referrer, root_email
)
SELECT 
    'Top Referral Organizations' as check_type,
    root_referrer as user_id,
    root_email as email,
    max_depth,
    total_referrals,
    total_referral_purchases,
    CASE 
        WHEN max_depth >= 4 THEN 'HAS_4TH_LEVEL_PLUS'
        ELSE 'MAX_3_LEVELS'
    END as organization_type
FROM max_depths
ORDER BY max_depth DESC, total_referrals DESC
LIMIT 10;

-- 4段目以降が存在するアカウントの詳細調査
WITH RECURSIVE deep_referral_analysis AS (
    SELECT 
        u.user_id,
        u.email,
        u.referrer_user_id,
        u.total_purchases,
        1 as level,
        COALESCE(r.user_id, 'ROOT') as root_referrer,
        COALESCE(r.email, 'NO_REFERRER') as root_email
    FROM users u
    LEFT JOIN users r ON u.referrer_user_id = r.user_id
    WHERE u.referrer_user_id IS NOT NULL
    
    UNION ALL
    
    SELECT 
        u.user_id,
        u.email,
        u.referrer_user_id,
        u.total_purchases,
        dra.level + 1,
        dra.root_referrer,
        dra.root_email
    FROM users u
    INNER JOIN deep_referral_analysis dra ON u.referrer_user_id = dra.user_id
    WHERE dra.level < 10
)
SELECT 
    'Level 4+ Purchase Analysis' as check_type,
    root_referrer,
    root_email,
    level,
    COUNT(*) as users_at_level,
    COALESCE(SUM(total_purchases), 0) as purchases_at_level,
    STRING_AGG(user_id || '($' || COALESCE(total_purchases, 0) || ')', ', ') as user_details
FROM deep_referral_analysis
WHERE level >= 4
GROUP BY root_referrer, root_email, level
ORDER BY root_referrer, level;

-- 全体統計
SELECT 
    'Overall Referral Statistics' as check_type,
    COUNT(DISTINCT CASE WHEN referrer_user_id IS NOT NULL THEN user_id END) as users_with_referrer,
    COUNT(DISTINCT referrer_user_id) as active_referrers,
    COUNT(DISTINCT user_id) as total_users,
    COALESCE(SUM(total_purchases), 0) as total_system_purchases
FROM users;

-- 簡単な紹介深度チェック
SELECT 
    'Simple Depth Check' as check_type,
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
WHERE u1.email = 'masakuma1108@gmail.com' OR u1.user_id IN (
    SELECT DISTINCT referrer_user_id FROM users WHERE referrer_user_id IS NOT NULL
)
GROUP BY u1.user_id, u1.email
HAVING COUNT(u4.user_id) > 0 OR u1.email = 'masakuma1108@gmail.com'
ORDER BY level4_count DESC, level3_count DESC;
