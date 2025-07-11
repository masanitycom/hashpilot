-- Level4以降の統計を無制限に集計するように修正

DROP FUNCTION IF EXISTS get_user_stats(TEXT);

CREATE OR REPLACE FUNCTION get_user_stats(target_user_id TEXT)
RETURNS TABLE (
    total_investment DECIMAL,
    direct_referrals INTEGER,
    total_referrals INTEGER,
    level1_investment DECIMAL,
    level2_investment DECIMAL,
    level3_investment DECIMAL,
    level4_plus_referrals INTEGER,
    level4_plus_investment DECIMAL
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE referral_tree AS (
        -- レベル1: 直接紹介者
        SELECT 
            u.user_id,
            u.total_purchases,
            1 as level_num
        FROM users u 
        WHERE u.referrer_user_id = target_user_id
        
        UNION ALL
        
        -- レベル2以降: 間接紹介者（無制限、ただし安全のため最大50階層）
        SELECT 
            u.user_id,
            u.total_purchases,
            rt.level_num + 1
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level_num < 50  -- 無限ループ防止のため50階層まで
    ),
    level_stats AS (
        SELECT 
            level_num,
            COUNT(*) as user_count,
            SUM(FLOOR(COALESCE(total_purchases, 0) / 1100) * 1000) as investment_amount
        FROM referral_tree
        GROUP BY level_num
    )
    SELECT 
        -- 本人の投資額
        FLOOR(COALESCE((SELECT total_purchases FROM users WHERE user_id = target_user_id), 0) / 1100) * 1000 as total_investment,
        -- 直接紹介者数
        COALESCE((SELECT user_count FROM level_stats WHERE level_num = 1), 0)::INTEGER as direct_referrals,
        -- 総紹介者数（すべての階層）
        COALESCE((SELECT SUM(user_count) FROM level_stats), 0)::INTEGER as total_referrals,
        -- Level1投資額
        COALESCE((SELECT investment_amount FROM level_stats WHERE level_num = 1), 0) as level1_investment,
        -- Level2投資額
        COALESCE((SELECT investment_amount FROM level_stats WHERE level_num = 2), 0) as level2_investment,
        -- Level3投資額
        COALESCE((SELECT investment_amount FROM level_stats WHERE level_num = 3), 0) as level3_investment,
        -- Level4以降の人数（すべて）
        COALESCE((SELECT SUM(user_count) FROM level_stats WHERE level_num >= 4), 0)::INTEGER as level4_plus_referrals,
        -- Level4以降の投資額合計（すべて）
        COALESCE((SELECT SUM(investment_amount) FROM level_stats WHERE level_num >= 4), 0) as level4_plus_investment;
END;
$$;

-- 権限付与
GRANT EXECUTE ON FUNCTION get_user_stats(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_stats(TEXT) TO anon;

-- テスト用：最大階層を確認する関数
CREATE OR REPLACE FUNCTION get_max_referral_depth()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    max_depth INTEGER := 0;
    current_depth INTEGER;
BEGIN
    -- すべてのルートユーザー（紹介者なし）から開始
    WITH RECURSIVE depth_check AS (
        -- ルートユーザー
        SELECT 
            user_id,
            0 as depth
        FROM users 
        WHERE referrer_user_id IS NULL
        
        UNION ALL
        
        -- 子ノード
        SELECT 
            u.user_id,
            dc.depth + 1
        FROM users u
        INNER JOIN depth_check dc ON u.referrer_user_id = dc.user_id
        WHERE dc.depth < 50  -- 安全のため50階層まで
    )
    SELECT MAX(depth) INTO max_depth FROM depth_check;
    
    RETURN COALESCE(max_depth, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION get_max_referral_depth() TO authenticated;