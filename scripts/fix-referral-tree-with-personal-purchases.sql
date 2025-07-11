-- 管理画面用の紹介ツリー関数を修正（personal_purchasesとsubtree_totalを追加）

DROP FUNCTION IF EXISTS get_referral_tree(text);

CREATE OR REPLACE FUNCTION get_referral_tree(root_user_id text)
RETURNS TABLE (
    user_id text,
    email text,
    full_name text,
    coinw_uid text,
    level_num integer,
    total_investment numeric,
    nft_count integer,
    path text,
    parent_user_id text,
    personal_purchases numeric,
    subtree_total numeric,
    referrer_id text,
    direct_referrals_count integer
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE referral_tree AS (
        -- Base case: direct referrals (level 1)
        SELECT 
            u.user_id::text,
            u.email::text,
            u.full_name::text,
            u.coinw_uid::text,
            1 as level_num,
            FLOOR(COALESCE(u.total_purchases, 0) / 1100) * 1000 as total_investment,
            FLOOR(COALESCE(u.total_purchases, 0) / 1100)::integer as nft_count,
            u.user_id::text as path,
            u.referrer_user_id::text as parent_user_id,
            COALESCE(u.total_purchases, 0) as personal_purchases
        FROM users u
        WHERE u.referrer_user_id = root_user_id
        
        UNION ALL
        
        -- Recursive case: indirect referrals (無制限、最大100レベル)
        SELECT 
            u.user_id::text,
            u.email::text,
            u.full_name::text,
            u.coinw_uid::text,
            rt.level_num + 1,
            FLOOR(COALESCE(u.total_purchases, 0) / 1100) * 1000 as total_investment,
            FLOOR(COALESCE(u.total_purchases, 0) / 1100)::integer as nft_count,
            (rt.path || '->' || u.user_id)::text as path,
            u.referrer_user_id::text as parent_user_id,
            COALESCE(u.total_purchases, 0) as personal_purchases
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level_num < 100
    ),
    -- 各ユーザーの下位ツリーの合計を計算
    subtree_totals AS (
        SELECT 
            rt1.user_id,
            COALESCE(SUM(rt2.personal_purchases), 0) as subtree_sum
        FROM referral_tree rt1
        LEFT JOIN referral_tree rt2 ON rt2.path LIKE rt1.user_id || '%' AND rt2.user_id != rt1.user_id
        GROUP BY rt1.user_id
    ),
    -- 直接紹介者数を計算
    direct_refs AS (
        SELECT 
            referrer_user_id,
            COUNT(*) as count
        FROM users
        WHERE referrer_user_id IS NOT NULL
        GROUP BY referrer_user_id
    )
    SELECT 
        rt.user_id,
        rt.email,
        rt.full_name,
        rt.coinw_uid,
        rt.level_num,
        rt.total_investment,
        rt.nft_count,
        rt.path,
        rt.parent_user_id,
        rt.personal_purchases,
        COALESCE(st.subtree_sum, 0) as subtree_total,
        rt.parent_user_id as referrer_id,
        COALESCE(dr.count, 0)::integer as direct_referrals_count
    FROM referral_tree rt
    LEFT JOIN subtree_totals st ON rt.user_id = st.user_id
    LEFT JOIN direct_refs dr ON rt.user_id = dr.referrer_user_id
    ORDER BY rt.level_num, rt.user_id;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION get_referral_tree(text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree(text) TO anon;