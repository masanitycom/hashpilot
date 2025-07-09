-- 重複したget_referral_tree関数を削除して、1つの正しい関数を作成

-- 1. 現在の関数の状態を確認
SELECT 
    proname as function_name,
    proargnames as parameter_names,
    pronargs as parameter_count,
    oid
FROM pg_proc 
WHERE proname = 'get_referral_tree'
ORDER BY oid;

-- 2. すべてのget_referral_tree関数を削除
DROP FUNCTION IF EXISTS get_referral_tree(TEXT);
DROP FUNCTION IF EXISTS get_referral_tree(VARCHAR);
DROP FUNCTION IF EXISTS get_referral_tree(VARCHAR(6));

-- 3. 正しい関数を1つだけ作成
CREATE OR REPLACE FUNCTION get_referral_tree(target_user_id TEXT)
RETURNS TABLE (
    user_id TEXT,
    email TEXT,
    full_name TEXT,
    coinw_uid TEXT,
    level_num INTEGER,
    path TEXT,
    referrer_id TEXT,
    personal_investment DECIMAL,
    subordinate_total DECIMAL,
    total_rewards DECIMAL,
    created_at TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE referral_tree AS (
        -- Level 1: 直接紹介者
        SELECT 
            u.user_id::TEXT,
            u.email::TEXT,
            COALESCE(u.full_name, '')::TEXT as full_name,
            COALESCE(u.coinw_uid, '')::TEXT as coinw_uid,
            1 as level_num,
            u.user_id::TEXT as path,
            target_user_id::TEXT as referrer_id,
            COALESCE(u.total_purchases, 0)::DECIMAL as personal_investment,
            0::DECIMAL as subordinate_total,
            0::DECIMAL as total_rewards,
            u.created_at
        FROM users u 
        WHERE u.referrer_user_id = target_user_id
        
        UNION ALL
        
        -- Level 2-3: 間接紹介者
        SELECT 
            u.user_id::TEXT,
            u.email::TEXT,
            COALESCE(u.full_name, '')::TEXT as full_name,
            COALESCE(u.coinw_uid, '')::TEXT as coinw_uid,
            rt.level_num + 1,
            rt.path || '->' || u.user_id::TEXT as path,
            rt.user_id::TEXT as referrer_id,
            COALESCE(u.total_purchases, 0)::DECIMAL as personal_investment,
            0::DECIMAL as subordinate_total,
            0::DECIMAL as total_rewards,
            u.created_at
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level_num < 3
    )
    SELECT 
        rt.user_id,
        rt.email,
        rt.full_name,
        rt.coinw_uid,
        rt.level_num,
        rt.path,
        rt.referrer_id,
        rt.personal_investment,
        rt.subordinate_total,
        rt.total_rewards,
        rt.created_at
    FROM referral_tree rt
    ORDER BY rt.level_num, rt.created_at;
END;
$$;

-- 4. 権限を設定
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO anon;

-- 5. 確認
SELECT 
    'Function cleaned and recreated successfully' as status,
    proname as function_name,
    proargnames as parameters
FROM pg_proc 
WHERE proname = 'get_referral_tree';