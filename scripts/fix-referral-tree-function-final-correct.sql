-- 紹介ツリー関数を完全に修正
DROP FUNCTION IF EXISTS get_referral_tree(TEXT);

CREATE OR REPLACE FUNCTION get_referral_tree(input_user_id TEXT)
RETURNS TABLE (
    level_num INTEGER,
    user_id TEXT,
    email TEXT,
    full_name TEXT,
    coinw_uid TEXT,
    total_purchases DECIMAL,
    nft_count INTEGER,
    created_at TIMESTAMP WITH TIME ZONE,
    parent_user_id TEXT,
    path TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE referral_tree AS (
        -- レベル1: 直接紹介者
        SELECT 
            1 as level_num,
            u.user_id::TEXT,
            u.email::TEXT,
            COALESCE(u.full_name, '')::TEXT as full_name,
            COALESCE(u.coinw_uid, '')::TEXT as coinw_uid,
            FLOOR(COALESCE(u.total_purchases, 0) / 1000) * 1000 as total_purchases,
            FLOOR(COALESCE(u.total_purchases, 0) / 1000) as nft_count,
            u.created_at,
            input_user_id::TEXT as parent_user_id,
            u.user_id::TEXT as path
        FROM users u 
        WHERE u.referrer_user_id = input_user_id
        
        UNION ALL
        
        -- レベル2以降: 間接紹介者
        SELECT 
            rt.level_num + 1,
            u.user_id::TEXT,
            u.email::TEXT,
            COALESCE(u.full_name, '')::TEXT as full_name,
            COALESCE(u.coinw_uid, '')::TEXT as coinw_uid,
            FLOOR(COALESCE(u.total_purchases, 0) / 1000) * 1000 as total_purchases,
            FLOOR(COALESCE(u.total_purchases, 0) / 1000) as nft_count,
            u.created_at,
            rt.user_id::TEXT as parent_user_id,
            rt.path || '.' || u.user_id::TEXT as path
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level_num < 10 -- 無限ループ防止
    )
    SELECT * FROM referral_tree ORDER BY level_num, created_at;
END;
$$;

-- 実行権限を設定
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO anon;
