-- 紹介組織の4段目以降分析（修正版）
WITH RECURSIVE referral_tree AS (
  -- Base case: Level 1 users (direct referrals)
  SELECT 
    u.user_id,
    u.email,
    u.user_id as root_user_id,
    u.email as root_email,
    1 as level,
    ARRAY[u.user_id::varchar] as path
  FROM users u
  WHERE u.referrer_user_id IS NOT NULL
  
  UNION ALL
  
  -- Recursive case: Find deeper levels
  SELECT 
    u.user_id,
    u.email,
    rt.root_user_id,
    rt.root_email,
    rt.level + 1,
    rt.path || u.user_id::varchar
  FROM users u
  INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
  WHERE rt.level < 10 -- Prevent infinite recursion
    AND NOT (u.user_id = ANY(rt.path)) -- Prevent cycles
),

-- 4段目以降のユーザーと購入額を集計
level4_plus_analysis AS (
  SELECT 
    rt.root_user_id,
    rt.root_email,
    COUNT(CASE WHEN rt.level = 4 THEN 1 END) as level4_count,
    COALESCE(SUM(CASE WHEN rt.level = 4 THEN p.amount_usd ELSE 0 END), 0) as level4_purchases,
    COUNT(CASE WHEN rt.level >= 4 THEN 1 END) as level4_plus_count,
    COALESCE(SUM(CASE WHEN rt.level >= 4 THEN p.amount_usd ELSE 0 END), 0) as level4_plus_purchases
  FROM referral_tree rt
  LEFT JOIN purchases p ON rt.user_id = p.user_id AND p.admin_approved = true
  WHERE rt.level >= 4
  GROUP BY rt.root_user_id, rt.root_email
),

-- 購入パターン分析
purchase_patterns AS (
  SELECT 
    'Purchase Pattern Analysis' as analysis_type,
    level4_purchases::text as purchase_amount,
    COUNT(*) as organizations_count,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()), 2) as percentage
  FROM level4_plus_analysis
  WHERE level4_purchases > 0
  GROUP BY level4_purchases
),

-- トップ組織の詳細
top_organizations AS (
  SELECT 
    'Top 4th Level Organizations' as analysis_type,
    root_email as purchase_amount,
    level4_count as organizations_count,
    level4_purchases as percentage
  FROM level4_plus_analysis
  WHERE level4_count > 0
  ORDER BY level4_purchases DESC, level4_count DESC
  LIMIT 10
)

-- 結果を返す
SELECT 
  analysis_type,
  purchase_amount,
  organizations_count,
  percentage
FROM purchase_patterns
ORDER BY percentage DESC

UNION ALL

SELECT 
  analysis_type,
  purchase_amount,
  organizations_count,
  percentage
FROM top_organizations;
