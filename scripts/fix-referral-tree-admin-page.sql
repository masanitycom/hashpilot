-- 管理者ページ用のget_referral_tree関数修正
-- ReferralNodeインターフェースに合わせて戻り値を修正

-- 1. 既存の関数を削除
DROP FUNCTION IF EXISTS get_referral_tree(TEXT);

-- 2. 管理者ページに合わせた関数を作成
CREATE OR REPLACE FUNCTION get_referral_tree(target_user_id TEXT)
RETURNS TABLE (
    level_num INTEGER,
    user_id TEXT,
    email TEXT,
    personal_purchases NUMERIC,
    subtree_total NUMERIC,
    referrer_id TEXT,
    direct_referrals_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE referral_tree AS (
        -- Level 1: 直接紹介者
        SELECT 
            1 as level_num,
            u.user_id::TEXT,
            u.email::TEXT,
            COALESCE(u.total_purchases, 0)::NUMERIC as personal_purchases,
            0::NUMERIC as subtree_total,
            target_user_id::TEXT as referrer_id,
            u.created_at
        FROM users u 
        WHERE u.referrer_user_id = target_user_id
        
        UNION ALL
        
        -- Level 2-10: 間接紹介者
        SELECT 
            rt.level_num + 1,
            u.user_id::TEXT,
            u.email::TEXT,
            COALESCE(u.total_purchases, 0)::NUMERIC as personal_purchases,
            0::NUMERIC as subtree_total,
            rt.user_id::TEXT as referrer_id,
            u.created_at
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level_num < 10
    ),
    -- 各ユーザーの直接紹介者数を計算
    direct_counts AS (
        SELECT 
            referrer_user_id as user_id,
            COUNT(*)::INTEGER as direct_count
        FROM users
        WHERE referrer_user_id IS NOT NULL
        GROUP BY referrer_user_id
    ),
    -- 各ユーザーの下位購入額合計を計算
    subtree_totals AS (
        SELECT 
            rt.referrer_id,
            SUM(rt.personal_purchases)::NUMERIC as subtree_sum
        FROM referral_tree rt
        GROUP BY rt.referrer_id
    )
    SELECT 
        rt.level_num,
        rt.user_id,
        rt.email,
        rt.personal_purchases,
        COALESCE(st.subtree_sum, 0)::NUMERIC as subtree_total,
        rt.referrer_id,
        COALESCE(dc.direct_count, 0)::INTEGER as direct_referrals_count
    FROM referral_tree rt
    LEFT JOIN direct_counts dc ON rt.user_id = dc.user_id
    LEFT JOIN subtree_totals st ON rt.user_id = st.referrer_id
    ORDER BY rt.level_num, rt.created_at;
END;
$$;

-- 3. 権限を設定
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO anon;

-- 4. get_referral_stats関数も確認・作成
CREATE OR REPLACE FUNCTION get_referral_stats(target_user_id TEXT)
RETURNS TABLE (
    total_direct_referrals INTEGER,
    total_indirect_referrals INTEGER,
    total_referral_purchases NUMERIC,
    max_tree_depth INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH tree_data AS (
        SELECT * FROM get_referral_tree(target_user_id)
    )
    SELECT 
        COUNT(CASE WHEN level_num = 1 THEN 1 END)::INTEGER as total_direct_referrals,
        COUNT(CASE WHEN level_num > 1 THEN 1 END)::INTEGER as total_indirect_referrals,
        SUM(personal_purchases)::NUMERIC as total_referral_purchases,
        COALESCE(MAX(level_num), 0)::INTEGER as max_tree_depth
    FROM tree_data;
END;
$$;

-- 5. 権限を設定
GRANT EXECUTE ON FUNCTION get_referral_stats(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_stats(TEXT) TO anon;

-- 6. 関数の動作確認
SELECT 'Function created successfully' as status;