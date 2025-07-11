-- 無制限の紹介ツリー表示関数（管理画面用）

-- 既存の関数を削除
DROP FUNCTION IF EXISTS get_referral_tree(text);

-- 新しい無制限版の関数を作成
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
            FLOOR(COALESCE(u.total_purchases, 0) / 1100) * 1000 as total_investment,
            FLOOR(COALESCE(u.total_purchases, 0) / 1100) as nft_count,
            u.user_id::text as path,
            u.referrer_user_id::text as parent_user_id
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
            FLOOR(COALESCE(u.total_purchases, 0) / 1100) as nft_count,
            (rt.path || '->' || u.user_id)::text as path,
            u.referrer_user_id::text as parent_user_id
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level_num < 100  -- 無限ループ防止のため100レベルまで
    )
    SELECT * FROM referral_tree
    ORDER BY level_num, user_id;
END;
$$;

-- ユーザー用の制限版関数（Level3まで）を別名で作成
DROP FUNCTION IF EXISTS get_referral_tree_user(text);

CREATE OR REPLACE FUNCTION get_referral_tree_user(root_user_id text)
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
            FLOOR(COALESCE(u.total_purchases, 0) / 1100) * 1000 as total_investment,
            FLOOR(COALESCE(u.total_purchases, 0) / 1100) as nft_count,
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
            FLOOR(COALESCE(u.total_purchases, 0) / 1100) * 1000 as total_investment,
            FLOOR(COALESCE(u.total_purchases, 0) / 1100) as nft_count,
            (rt.path || '->' || u.user_id)::text as path,
            u.referrer_user_id::text as parent_user_id
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level_num < 3  -- ユーザー用は3レベルまで
    )
    SELECT * FROM referral_tree
    ORDER BY level_num, user_id;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION get_referral_tree(text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree(text) TO anon;
GRANT EXECUTE ON FUNCTION get_referral_tree_user(text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree_user(text) TO anon;

-- テスト: 実際の最大レベルを確認
DROP FUNCTION IF EXISTS check_max_referral_level(text);

CREATE OR REPLACE FUNCTION check_max_referral_level(target_user_id text)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    max_level integer;
BEGIN
    WITH RECURSIVE referral_check AS (
        SELECT 
            user_id,
            1 as level_num
        FROM users
        WHERE referrer_user_id = target_user_id
        
        UNION ALL
        
        SELECT 
            u.user_id,
            rc.level_num + 1
        FROM users u
        INNER JOIN referral_check rc ON u.referrer_user_id = rc.user_id
        WHERE rc.level_num < 100
    )
    SELECT COALESCE(MAX(level_num), 0) INTO max_level FROM referral_check;
    
    RETURN max_level;
END;
$$;

GRANT EXECUTE ON FUNCTION check_max_referral_level(text) TO authenticated;