-- 本番環境完全修正用SQL
-- get_referral_treeとget_referral_stats両方を修正

-- 1. 既存の関数をすべて削除
DROP FUNCTION IF EXISTS get_referral_tree(TEXT);
DROP FUNCTION IF EXISTS get_referral_stats(TEXT);

-- 2. get_referral_tree関数を作成（本番環境で動作する版）
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

-- 3. get_referral_stats関数を作成
CREATE OR REPLACE FUNCTION get_referral_stats(target_user_id TEXT)
RETURNS TABLE (
    total_direct_referrals INTEGER,
    total_indirect_referrals INTEGER,
    total_referral_purchases DECIMAL,
    max_tree_depth INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH tree_data AS (
        SELECT * FROM get_referral_tree(target_user_id)
    )
    SELECT 
        (SELECT COUNT(*)::INTEGER FROM tree_data WHERE level_num = 1) as total_direct_referrals,
        (SELECT COUNT(*)::INTEGER FROM tree_data WHERE level_num > 1) as total_indirect_referrals,
        (SELECT COALESCE(SUM(personal_investment), 0::DECIMAL) FROM tree_data) as total_referral_purchases,
        (SELECT COALESCE(MAX(level_num), 0)::INTEGER FROM tree_data) as max_tree_depth;
END;
$$;

-- 4. 権限を設定
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION get_referral_stats(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_stats(TEXT) TO anon;

-- 5. 関数の作成確認
SELECT 
    'Functions restored successfully' as status,
    proname as function_name,
    proargnames as parameters
FROM pg_proc 
WHERE proname IN ('get_referral_tree', 'get_referral_stats')
ORDER BY proname;

-- 6. 動作テスト
SELECT 
    'Tree test' as test_type,
    user_id,
    email,
    level_num,
    personal_investment
FROM get_referral_tree('7A9637')
ORDER BY level_num, created_at
LIMIT 5;

SELECT 
    'Stats test' as test_type,
    total_direct_referrals,
    total_indirect_referrals,
    total_referral_purchases,
    max_tree_depth
FROM get_referral_stats('7A9637');