-- Drop the function if it exists and recreate it
DROP FUNCTION IF EXISTS public.get_referral_tree(text);

-- Create the get_referral_tree function
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
            u.user_id::text as user_id,
            u.email::text as email,
            COALESCE(u.full_name, '')::text as full_name,
            COALESCE(u.coinw_uid, '')::text as coinw_uid,
            1 as level_num,
            FLOOR(COALESCE(u.total_purchases, 0) / 1000) * 1000 as total_investment,
            FLOOR(COALESCE(u.total_purchases, 0) / 1000) as nft_count,
            u.user_id::text as path,
            COALESCE(u.referrer_user_id, '')::text as parent_user_id
        FROM users u
        WHERE u.referrer_user_id = root_user_id
        
        UNION ALL
        
        -- Recursive case: indirect referrals (levels 2, 3)
        SELECT 
            u.user_id::text as user_id,
            u.email::text as email,
            COALESCE(u.full_name, '')::text as full_name,
            COALESCE(u.coinw_uid, '')::text as coinw_uid,
            rt.level_num + 1 as level_num,
            FLOOR(COALESCE(u.total_purchases, 0) / 1000) * 1000 as total_investment,
            FLOOR(COALESCE(u.total_purchases, 0) / 1000) as nft_count,
            (rt.path || '->' || u.user_id)::text as path,
            COALESCE(u.referrer_user_id, '')::text as parent_user_id
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level_num < 3  -- Limit to 3 levels for tree display
    )
    SELECT * FROM referral_tree
    ORDER BY level_num, user_id;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_referral_tree(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_referral_tree(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_referral_tree(text) TO service_role;

-- Test the function
SELECT * FROM public.get_referral_tree('test') LIMIT 1;
