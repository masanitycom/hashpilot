-- 正確な型定義で紹介ツリー関数を作成

-- 既存の関数を削除
DROP FUNCTION IF EXISTS get_referral_tree(TEXT);
DROP FUNCTION IF EXISTS get_referral_stats(TEXT);

-- 紹介ツリーデータを取得する関数（正確な型定義）
CREATE OR REPLACE FUNCTION get_referral_tree(target_user_id VARCHAR(6))
RETURNS TABLE (
    level_num INTEGER,
    user_id VARCHAR(6),
    email VARCHAR(255),
    personal_purchases NUMERIC,
    subtree_total NUMERIC,
    referrer_id VARCHAR(6),
    direct_referrals_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE referral_tree AS (
        -- 直接紹介されたユーザー（レベル1）
        SELECT 
            1 as level_num,
            u.user_id::VARCHAR(6),
            u.email::VARCHAR(255),
            COALESCE(
                (SELECT SUM(p.amount_usd::NUMERIC) 
                 FROM purchases p 
                 WHERE p.user_id = u.user_id AND p.admin_approved = true), 
                0::NUMERIC
            ) as personal_purchases,
            0::NUMERIC as subtree_total,
            u.referrer_user_id::VARCHAR(6) as referrer_id,
            0 as direct_referrals_count
        FROM users u
        WHERE u.referrer_user_id = target_user_id
        
        UNION ALL
        
        -- 間接紹介されたユーザー（レベル2以降）
        SELECT 
            rt.level_num + 1,
            u.user_id::VARCHAR(6),
            u.email::VARCHAR(255),
            COALESCE(
                (SELECT SUM(p.amount_usd::NUMERIC) 
                 FROM purchases p 
                 WHERE p.user_id = u.user_id AND p.admin_approved = true), 
                0::NUMERIC
            ) as personal_purchases,
            0::NUMERIC as subtree_total,
            u.referrer_user_id::VARCHAR(6) as referrer_id,
            0 as direct_referrals_count
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level_num < 3  -- 最大3レベルまで
    )
    SELECT 
        rt.level_num,
        rt.user_id,
        rt.email,
        rt.personal_purchases,
        -- 各ユーザーの下位ツリーの合計を計算
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

-- 紹介ツリーの統計情報を取得する関数（正確な型定義）
CREATE OR REPLACE FUNCTION get_referral_stats(target_user_id VARCHAR(6))
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

-- 関数の実行権限を設定
GRANT EXECUTE ON FUNCTION get_referral_tree(VARCHAR(6)) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_stats(VARCHAR(6)) TO authenticated;

-- テスト実行（2BF53Bユーザーで）
SELECT 
    'Referral Tree Test' as check_type,
    *
FROM get_referral_tree('2BF53B');

SELECT 
    'Referral Stats Test' as check_type,
    *
FROM get_referral_stats('2BF53B');
