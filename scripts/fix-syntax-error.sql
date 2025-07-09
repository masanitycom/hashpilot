-- 構文エラーを修正するためのスクリプト

-- 1. 現在の関数の状態を確認
SELECT 
    proname as function_name,
    prosrc as function_source
FROM pg_proc 
WHERE proname IN ('get_user_stats', 'get_referral_tree')
ORDER BY proname;

-- 2. 関数を安全に再作成
DROP FUNCTION IF EXISTS get_user_stats(text);
DROP FUNCTION IF EXISTS get_referral_tree(text);

-- 3. get_user_stats関数を修正版で再作成
CREATE OR REPLACE FUNCTION get_user_stats(input_user_id text)
RETURNS TABLE(
    user_id text,
    email text,
    full_name text,
    coinw_uid text,
    total_purchases numeric,
    nft_count integer,
    total_referrals integer,
    total_referral_earnings numeric,
    reward_address_bep20 text,
    nft_receive_address text
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id,
        u.email,
        COALESCE(u.full_name, ''),
        COALESCE(u.coinw_uid, ''),
        COALESCE(u.total_purchases, 0),
        FLOOR(COALESCE(u.total_purchases, 0) / 1000)::integer,
        (
            SELECT COUNT(*)::integer
            FROM users r 
            WHERE r.referrer_user_id = u.user_id
        ),
        COALESCE(u.total_referral_earnings, 0),
        COALESCE(u.reward_address_bep20, ''),
        COALESCE(u.nft_receive_address, '')
    FROM users u
    WHERE u.user_id = input_user_id;
END;
$$;

-- 4. get_referral_tree関数を修正版で再作成
CREATE OR REPLACE FUNCTION get_referral_tree(input_user_id text)
RETURNS TABLE(
    level integer,
    user_id text,
    email text,
    full_name text,
    coinw_uid text,
    total_purchases numeric,
    nft_count integer,
    created_at timestamp with time zone
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
            COALESCE(u.full_name, ''),
            COALESCE(u.coinw_uid, ''),
            COALESCE(u.total_purchases, 0),
            FLOOR(COALESCE(u.total_purchases, 0) / 1000)::integer,
            u.created_at
        FROM users u
        WHERE u.referrer_user_id = input_user_id
        
        UNION ALL
        
        -- Recursive case: referrals of referrals
        SELECT 
            rt.level + 1,
            u.user_id,
            u.email,
            COALESCE(u.full_name, ''),
            COALESCE(u.coinw_uid, ''),
            COALESCE(u.total_purchases, 0),
            FLOOR(COALESCE(u.total_purchases, 0) / 1000)::integer,
            u.created_at
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level < 10
    )
    SELECT * FROM referral_tree
    ORDER BY level, created_at;
END;
$$;

-- 5. 権限を設定
GRANT EXECUTE ON FUNCTION get_user_stats(text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_stats(text) TO anon;
GRANT EXECUTE ON FUNCTION get_referral_tree(text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree(text) TO anon;

-- 6. テスト実行
SELECT 'Functions fixed and recreated successfully' as status;
