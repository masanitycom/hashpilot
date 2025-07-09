-- ユーザー統計関数を修正（UUID型の問題を解決）
DROP FUNCTION IF EXISTS get_user_stats(TEXT);

CREATE OR REPLACE FUNCTION get_user_stats(target_user_id TEXT)
RETURNS TABLE (
    total_investment DECIMAL,
    direct_referrals INTEGER,
    total_referrals INTEGER,
    total_referral_investment DECIMAL,
    estimated_rewards DECIMAL
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
        
        -- レベル2以降: 間接紹介者
        SELECT 
            u.user_id,
            u.total_purchases,
            rt.level_num + 1
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level_num < 10 -- 無限ループ防止
    ),
    stats AS (
        SELECT 
            -- 本人の投資額
            FLOOR(COALESCE((SELECT total_purchases FROM users WHERE user_id = target_user_id), 0) / 1000) * 1000 as user_investment,
            -- 直接紹介者数
            (SELECT COUNT(*) FROM referral_tree WHERE level_num = 1)::INTEGER as direct_count,
            -- 総紹介者数
            (SELECT COUNT(*) FROM referral_tree)::INTEGER as total_count,
            -- 紹介者の総投資額
            COALESCE((SELECT SUM(FLOOR(total_purchases / 1000) * 1000) FROM referral_tree), 0) as referral_investment
    )
    SELECT 
        s.user_investment as total_investment,
        s.direct_count as direct_referrals,
        s.total_count as total_referrals,
        s.referral_investment as total_referral_investment,
        -- 推定報酬（後で実装）
        0::DECIMAL as estimated_rewards
    FROM stats s;
END;
$$;

-- 実行権限を設定
GRANT EXECUTE ON FUNCTION get_user_stats(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_stats(TEXT) TO anon;
