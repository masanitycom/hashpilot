-- 1. 現在のデータ状況を確認
SELECT 
    'Current user data' as info,
    id, 
    user_id, 
    email,
    referrer_user_id,
    total_purchases
FROM users 
WHERE id = '7241f7f8-d05f-4c62-ac32-c2f8d8a93323'
OR user_id = '7A9637';

-- 2. get_referral_tree関数を修正
DROP FUNCTION IF EXISTS get_referral_tree(TEXT);

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

GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_referral_tree(TEXT) TO anon;

-- 3. テスト用データを作成（リファラルツリーを見るため）
INSERT INTO users (id, user_id, email, referrer_user_id, total_purchases, is_active, created_at, updated_at)
VALUES 
    ('11111111-1111-1111-1111-111111111111', 'TEST01', 'test1@example.com', '7A9637', 500, true, NOW(), NOW()),
    ('22222222-2222-2222-2222-222222222222', 'TEST02', 'test2@example.com', '7A9637', 2200, true, NOW(), NOW()),
    ('33333333-3333-3333-3333-333333333333', 'TEST03', 'test3@example.com', 'TEST01', 1100, true, NOW(), NOW())
ON CONFLICT (id) DO NOTHING;

-- 4. 関数をテスト
SELECT 
    'Test results - Level 1' as info,
    user_id,
    email,
    level_num,
    referrer_id,
    personal_investment
FROM get_referral_tree('7A9637')
ORDER BY level_num, created_at;