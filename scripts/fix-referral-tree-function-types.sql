-- 既存の関数を削除
DROP FUNCTION IF EXISTS get_referral_tree(TEXT);

-- 新しい関数を作成（親子関係を含む）
CREATE OR REPLACE FUNCTION get_referral_tree(input_user_id TEXT)
RETURNS TABLE(
    level INTEGER,
    user_id TEXT,
    email TEXT,
    full_name TEXT,
    coinw_uid TEXT,
    total_purchases NUMERIC,
    nft_count INTEGER,
    created_at TIMESTAMP WITH TIME ZONE,
    parent_user_id TEXT,
    path TEXT[]
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE referral_tree AS (
        -- ベースケース: 直接の紹介者（レベル1）
        SELECT 
            1 as level,
            u.user_id,
            u.email,
            COALESCE(u.full_name, '') as full_name,
            COALESCE(u.coinw_uid, '') as coinw_uid,
            COALESCE(u.total_purchases, 0) as total_purchases,
            COALESCE(FLOOR(u.total_purchases / 1000), 0)::INTEGER as nft_count,
            u.created_at,
            u.referrer_user_id as parent_user_id,
            ARRAY[u.user_id] as path
        FROM users u
        WHERE u.referrer_user_id = input_user_id
        
        UNION ALL
        
        -- 再帰ケース: 間接の紹介者（レベル2以上）
        SELECT 
            rt.level + 1,
            u.user_id,
            u.email,
            COALESCE(u.full_name, '') as full_name,
            COALESCE(u.coinw_uid, '') as coinw_uid,
            COALESCE(u.total_purchases, 0) as total_purchases,
            COALESCE(FLOOR(u.total_purchases / 1000), 0)::INTEGER as nft_count,
            u.created_at,
            u.referrer_user_id as parent_user_id,
            rt.path || u.user_id as path
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level < 20  -- 無限ループ防止
    )
    SELECT 
        rt.level,
        rt.user_id,
        rt.email,
        rt.full_name,
        rt.coinw_uid,
        rt.total_purchases,
        rt.nft_count,
        rt.created_at,
        rt.parent_user_id,
        rt.path
    FROM referral_tree rt
    ORDER BY rt.level, rt.created_at;
END;
$$;

-- 権限設定
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO anon;
