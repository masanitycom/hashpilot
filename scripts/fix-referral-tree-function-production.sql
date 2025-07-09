-- 紹介ツリー関数を修正（UUID型の問題を解決）
DROP FUNCTION IF EXISTS get_referral_tree(TEXT);

CREATE OR REPLACE FUNCTION get_referral_tree(root_user_id TEXT)
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
        -- レベル1: 直接紹介者
        SELECT 
            u.user_id::TEXT,
            u.email::TEXT,
            COALESCE(u.full_name, '')::TEXT as full_name,
            COALESCE(u.coinw_uid, '')::TEXT as coinw_uid,
            1 as level_num,
            ROW_NUMBER() OVER (ORDER BY u.created_at)::TEXT as path,
            root_user_id::TEXT as referrer_id,
            FLOOR(COALESCE(u.total_purchases, 0) / 1000) * 1000 as personal_investment,
            0::DECIMAL as subordinate_total,
            0::DECIMAL as total_rewards,
            u.created_at
        FROM users u 
        WHERE u.referrer_user_id = root_user_id
        
        UNION ALL
        
        -- レベル2以降: 間接紹介者
        SELECT 
            u.user_id::TEXT,
            u.email::TEXT,
            COALESCE(u.full_name, '')::TEXT as full_name,
            COALESCE(u.coinw_uid, '')::TEXT as coinw_uid,
            rt.level_num + 1,
            rt.path || '.' || ROW_NUMBER() OVER (PARTITION BY rt.user_id ORDER BY u.created_at)::TEXT,
            rt.user_id::TEXT,
            FLOOR(COALESCE(u.total_purchases, 0) / 1000) * 1000 as personal_investment,
            0::DECIMAL as subordinate_total,
            0::DECIMAL as total_rewards,
            u.created_at
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level_num < 10 -- 無限ループ防止
    )
    SELECT * FROM referral_tree ORDER BY path;
END;
$$;

-- 実行権限を設定
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO anon;
