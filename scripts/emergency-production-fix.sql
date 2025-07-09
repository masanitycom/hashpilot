-- 本番環境緊急修正SQL
-- get_referral_tree関数を安全な状態に戻す

-- 1. 現在の状況確認
SELECT 
    'Current functions' as info,
    proname as function_name,
    proargnames as parameters,
    pronargs as param_count
FROM pg_proc 
WHERE proname IN ('get_referral_tree', 'get_referral_stats')
ORDER BY proname;

-- 2. 既存関数を全て削除
DROP FUNCTION IF EXISTS get_referral_tree(TEXT);
DROP FUNCTION IF EXISTS get_referral_tree(VARCHAR);
DROP FUNCTION IF EXISTS get_referral_tree(character varying);

-- 3. 最もシンプルで安全な関数を作成
CREATE OR REPLACE FUNCTION get_referral_tree(target_user_id TEXT)
RETURNS TABLE (
    user_id TEXT,
    email TEXT,
    level_num INTEGER,
    personal_investment DECIMAL,
    referrer_id TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE referral_tree AS (
        -- Level 1
        SELECT 
            u.user_id::TEXT as user_id,
            u.email::TEXT as email,
            1 as level_num,
            COALESCE(u.total_purchases, 0)::DECIMAL as personal_investment,
            target_user_id::TEXT as referrer_id
        FROM users u 
        WHERE u.referrer_user_id = target_user_id
        
        UNION ALL
        
        -- Level 2-3
        SELECT 
            u.user_id::TEXT as user_id,
            u.email::TEXT as email,
            rt.level_num + 1 as level_num,
            COALESCE(u.total_purchases, 0)::DECIMAL as personal_investment,
            rt.user_id::TEXT as referrer_id
        FROM users u
        INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        WHERE rt.level_num < 3
    )
    SELECT 
        rt.user_id,
        rt.email,
        rt.level_num,
        rt.personal_investment,
        rt.referrer_id
    FROM referral_tree rt
    ORDER BY rt.level_num, rt.user_id;
END;
$$;

-- 4. 権限設定
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO anon;

-- 5. 動作確認
SELECT 
    'Test results' as info,
    user_id,
    email,
    level_num,
    personal_investment
FROM get_referral_tree('7A9637')
ORDER BY level_num
LIMIT 10;