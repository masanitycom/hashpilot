-- 既存の関数を削除してから再作成
DROP FUNCTION IF EXISTS get_user_stats(text);
DROP FUNCTION IF EXISTS get_referral_tree(text);

-- get_user_stats関数を再作成
CREATE OR REPLACE FUNCTION get_user_stats(input_user_id TEXT)
RETURNS TABLE(
    user_id TEXT,
    email TEXT,
    full_name TEXT,
    coinw_uid TEXT,
    total_purchases NUMERIC,
    nft_count INTEGER,
    total_referrals INTEGER,
    total_referral_earnings NUMERIC,
    reward_address_bep20 TEXT,
    nft_receive_address TEXT
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id::TEXT,
        u.email::TEXT,
        COALESCE(u.full_name, '')::TEXT,
        COALESCE(u.coinw_uid, '')::TEXT,
        COALESCE(u.total_purchases, 0)::NUMERIC,
        FLOOR(COALESCE(u.total_purchases, 0) / 1000)::INTEGER as nft_count,
        (
            SELECT COUNT(*)::INTEGER
            FROM users r 
            WHERE r.referrer_user_id = u.user_id
        ),
        COALESCE(u.total_referral_earnings, 0)::NUMERIC,
        COALESCE(u.reward_address_bep20, '')::TEXT,
        COALESCE(u.nft_receive_address, '')::TEXT
    FROM users u
    WHERE u.id::TEXT = input_user_id::TEXT
    OR u.user_id = input_user_id;
END;
$$;

-- get_referral_tree関数を再作成
CREATE OR REPLACE FUNCTION get_referral_tree(input_user_id TEXT)
RETURNS TABLE(
    level INTEGER,
    user_id TEXT,
    email TEXT,
    full_name TEXT,
    coinw_uid TEXT,
    total_purchases NUMERIC,
    nft_count INTEGER,
    created_at TIMESTAMP WITH TIME ZONE
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE referral_tree AS (
        -- Base case: direct referrals (level 1)
        SELECT 
            1 as level,
            u.user_id,
            u.email,
            COALESCE(u.full_name, '') as full_name,
            COALESCE(u.coinw_uid, '') as coinw_uid,
            COALESCE(u.total_purchases, 0) as total_purchases,
            FLOOR(COALESCE(u.total_purchases, 0) / 1000)::INTEGER as nft_count,
            u.created_at
        FROM users u
        WHERE u.referrer_user_id = input_user_id
        
        UNION ALL
        
        -- Recursive case: referrals of referrals
        SELECT 
            rt.level + 1,
            u.user_id,
            u.email,
            COALESCE(u.full_name, '') as full_name,
            COALESCE(u.coinw_uid, '') as coinw_uid,
            COALESCE(u.total_purchases, 0) as total_purchases,
            FLOOR(COALESCE(u.total_purchases, 0) / 1000)::INTEGER as nft_count,
            u.created_at
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level < 10  -- Prevent infinite recursion
    )
    SELECT * FROM referral_tree
    ORDER BY level, created_at;
END;
$$;

-- 実行権限を設定
GRANT EXECUTE ON FUNCTION get_user_stats(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_stats(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO anon;

-- 確認
SELECT 'Functions recreated successfully' as status;
