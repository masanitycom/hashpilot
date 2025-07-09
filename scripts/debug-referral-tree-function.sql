-- 既存の関数を確認（修正版）
SELECT 
    proname as function_name,
    pronargs as num_args
FROM pg_proc 
WHERE proname = 'get_referral_tree';

-- 簡単なテスト実行
SELECT 'Function Test' as test_type, * FROM get_referral_tree('2BF53B');

-- 関数を再作成（修正版）
DROP FUNCTION IF EXISTS get_referral_tree(TEXT);
DROP FUNCTION IF EXISTS get_referral_stats(TEXT);

-- 修正版の関数を作成
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
        -- レベル1: 直接紹介されたユーザー
        SELECT 
            1 as level_num,
            u.user_id,
            u.email,
            COALESCE(
                (SELECT SUM(p.amount_usd::NUMERIC) 
                 FROM purchases p 
                 WHERE p.user_id = u.user_id AND p.admin_approved = true), 
                0::NUMERIC
            ) as personal_purchases,
            u.referrer_user_id as referrer_id
        FROM users u
        WHERE u.referrer_user_id = target_user_id
        
        UNION ALL
        
        -- レベル2以降: 間接紹介されたユーザー
        SELECT 
            rt.level_num + 1,
            u.user_id,
            u.email,
            COALESCE(
                (SELECT SUM(p.amount_usd::NUMERIC) 
                 FROM purchases p 
                 WHERE p.user_id = u.user_id AND p.admin_approved = true), 
                0::NUMERIC
            ) as personal_purchases,
            u.referrer_user_id as referrer_id
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level_num < 3
    )
    SELECT 
        rt.level_num,
        rt.user_id,
        rt.email,
        rt.personal_purchases,
        -- 下位ツリーの合計を計算
        COALESCE(
            (SELECT SUM(sub.personal_purchases) 
             FROM referral_tree sub 
             WHERE sub.referrer_id = rt.user_id), 
            0::NUMERIC
        ) as subtree_total,
        rt.referrer_id,
        -- 直接紹介した人数
        (SELECT COUNT(*)::INTEGER 
         FROM users direct 
         WHERE direct.referrer_user_id = rt.user_id) as direct_referrals_count
    FROM referral_tree rt
    ORDER BY rt.level_num, rt.user_id;
END;
$$;

-- 統計関数も修正
CREATE OR REPLACE FUNCTION get_referral_stats(target_user_id TEXT)
RETURNS TABLE (
    total_direct_referrals INTEGER,
    total_indirect_referrals INTEGER,
    total_referral_purchases NUMERIC,
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
        (SELECT COALESCE(SUM(personal_purchases), 0::NUMERIC) FROM tree_data) as total_referral_purchases,
        (SELECT COALESCE(MAX(level_num), 0)::INTEGER FROM tree_data) as max_tree_depth;
END;
$$;

-- 権限を再設定
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_stats(TEXT) TO authenticated;

-- 最終テスト
SELECT 'Final Test' as test_type, * FROM get_referral_tree('2BF53B') LIMIT 5;
SELECT 'Stats Test' as test_type, * FROM get_referral_stats('2BF53B');
