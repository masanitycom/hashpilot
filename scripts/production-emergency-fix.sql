-- 本番環境緊急修正用SQL
-- 安全にget_referral_tree関数を元に戻す

-- 1. 現在の関数の状態を確認
SELECT 
    proname as function_name,
    proargnames as parameter_names,
    pronargs as parameter_count
FROM pg_proc 
WHERE proname = 'get_referral_tree';

-- 2. 既存の関数を削除
DROP FUNCTION IF EXISTS get_referral_tree(TEXT);

-- 3. 元の安全な関数を再作成（本番環境で動作していた版）
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
            0 as direct_referrals_count
        FROM users u 
        WHERE u.referrer_user_id = target_user_id
        
        UNION ALL
        
        -- Level 2-3: 間接紹介者
        SELECT 
            rt.level_num + 1,
            u.user_id::TEXT,
            u.email::TEXT,
            COALESCE(u.total_purchases, 0)::NUMERIC as personal_purchases,
            0::NUMERIC as subtree_total,
            rt.user_id::TEXT as referrer_id,
            0 as direct_referrals_count
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level_num < 3
    )
    SELECT 
        rt.level_num,
        rt.user_id,
        rt.email,
        rt.personal_purchases,
        rt.subtree_total,
        rt.referrer_id,
        rt.direct_referrals_count
    FROM referral_tree rt
    ORDER BY rt.level_num, rt.user_id;
END;
$$;

-- 4. 権限を設定
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO anon;

-- 5. 関数の復旧確認
SELECT 
    'Function restored to safe state' as status,
    proname as function_name,
    proargnames as parameters
FROM pg_proc 
WHERE proname = 'get_referral_tree';