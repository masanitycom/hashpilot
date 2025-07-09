-- Create the get_referral_tree function that was missing
CREATE OR REPLACE FUNCTION public.get_referral_tree(root_user_id text)
RETURNS TABLE (
    user_id text,
    email text,
    full_name text,
    coinw_uid text,
    level_num integer,
    total_investment numeric,
    nft_count integer,
    path text,
    parent_user_id text
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
            FLOOR(COALESCE(u.total_purchases, 0) / 1000) * 1000 as total_investment,
            FLOOR(COALESCE(u.total_purchases, 0) / 1000) as nft_count,
            u.user_id::text as path,
            u.referrer_user_id::text as parent_user_id
        FROM users u
        WHERE u.referrer_user_id = root_user_id
        
        UNION ALL
        
        -- Recursive case: indirect referrals (levels 2, 3)
        SELECT 
            u.user_id::text,
            u.email::text,
            u.full_name::text,
            u.coinw_uid::text,
            rt.level_num + 1,
            FLOOR(COALESCE(u.total_purchases, 0) / 1000) * 1000 as total_investment,
            FLOOR(COALESCE(u.total_purchases, 0) / 1000) as nft_count,
            (rt.path || '->' || u.user_id)::text as path,
            u.referrer_user_id::text as parent_user_id
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level_num < 3  -- Limit to 3 levels for tree display
    )
    SELECT * FROM referral_tree
    ORDER BY level_num, user_id;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_referral_tree(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_referral_tree(text) TO anon;
