-- 🔍 紹介報酬システム全体調査
-- 2025年7月16日

-- 1. 全ユーザーの紹介ツリー構造確認
SELECT 
    '=== 全ユーザーの紹介ツリー構造 ===' as investigation,
    u0.user_id as root_user,
    u0.email as root_email,
    u1.user_id as level1_user,
    u1.email as level1_email,
    u2.user_id as level2_user, 
    u2.email as level2_email,
    u3.user_id as level3_user,
    u3.email as level3_email,
    u0.has_approved_nft as root_active,
    u1.has_approved_nft as level1_active,
    u2.has_approved_nft as level2_active,
    u3.has_approved_nft as level3_active
FROM users u0
LEFT JOIN users u1 ON u1.referrer_user_id = u0.user_id
LEFT JOIN users u2 ON u2.referrer_user_id = u1.user_id
LEFT JOIN users u3 ON u3.referrer_user_id = u2.user_id
WHERE u0.has_approved_nft = true
AND (u1.user_id IS NOT NULL OR u2.user_id IS NOT NULL OR u3.user_id IS NOT NULL)
ORDER BY u0.user_id, u1.user_id, u2.user_id, u3.user_id;

-- 2. Level1紹介者を持つ全ユーザーの利益記録確認
SELECT 
    '=== Level1紹介者の利益記録 ===' as investigation,
    u0.user_id as referrer,
    u0.email as referrer_email,
    u1.user_id as level1_user,
    u1.email as level1_email,
    COUNT(udp.date) as profit_days,
    COALESCE(SUM(udp.daily_profit), 0) as total_profit,
    -- 紹介者が受け取るべき報酬（20%）
    COALESCE(SUM(udp.daily_profit), 0) * 0.20 as expected_level1_bonus
FROM users u0
JOIN users u1 ON u1.referrer_user_id = u0.user_id
LEFT JOIN user_daily_profit udp ON u1.user_id = udp.user_id
WHERE u0.has_approved_nft = true
AND u1.has_approved_nft = true
GROUP BY u0.user_id, u0.email, u1.user_id, u1.email
ORDER BY total_profit DESC;

-- 3. Level2紹介者を持つ全ユーザーの利益記録確認
SELECT 
    '=== Level2紹介者の利益記録 ===' as investigation,
    u0.user_id as root_referrer,
    u0.email as root_referrer_email,
    u1.user_id as level1_referrer,
    u2.user_id as level2_user,
    u2.email as level2_email,
    COUNT(udp.date) as profit_days,
    COALESCE(SUM(udp.daily_profit), 0) as total_profit,
    -- root_referrerが受け取るべき報酬（10%）
    COALESCE(SUM(udp.daily_profit), 0) * 0.10 as expected_level2_bonus
FROM users u0
JOIN users u1 ON u1.referrer_user_id = u0.user_id
JOIN users u2 ON u2.referrer_user_id = u1.user_id
LEFT JOIN user_daily_profit udp ON u2.user_id = udp.user_id
WHERE u0.has_approved_nft = true
AND u1.has_approved_nft = true
AND u2.has_approved_nft = true
GROUP BY u0.user_id, u0.email, u1.user_id, u2.user_id, u2.email
ORDER BY total_profit DESC;

-- 4. Level3紹介者を持つ全ユーザーの利益記録確認
SELECT 
    '=== Level3紹介者の利益記録 ===' as investigation,
    u0.user_id as root_referrer,
    u0.email as root_referrer_email,
    u1.user_id as level1_referrer,
    u2.user_id as level2_referrer,
    u3.user_id as level3_user,
    u3.email as level3_email,
    COUNT(udp.date) as profit_days,
    COALESCE(SUM(udp.daily_profit), 0) as total_profit,
    -- root_referrerが受け取るべき報酬（5%）
    COALESCE(SUM(udp.daily_profit), 0) * 0.05 as expected_level3_bonus
FROM users u0
JOIN users u1 ON u1.referrer_user_id = u0.user_id
JOIN users u2 ON u2.referrer_user_id = u1.user_id
JOIN users u3 ON u3.referrer_user_id = u2.user_id
LEFT JOIN user_daily_profit udp ON u3.user_id = udp.user_id
WHERE u0.has_approved_nft = true
AND u1.has_approved_nft = true
AND u2.has_approved_nft = true
AND u3.has_approved_nft = true
GROUP BY u0.user_id, u0.email, u1.user_id, u2.user_id, u3.user_id, u3.email
ORDER BY total_profit DESC;

-- 5. 全ユーザーの実際の利益 vs 期待利益比較
WITH user_profits AS (
    SELECT 
        u.user_id,
        u.email,
        -- 個人利益
        COALESCE(SUM(udp.daily_profit), 0) as personal_profit,
        -- Level1紹介報酬
        COALESCE((
            SELECT SUM(udp1.daily_profit) * 0.20 
            FROM users u1 
            LEFT JOIN user_daily_profit udp1 ON u1.user_id = udp1.user_id 
            WHERE u1.referrer_user_id = u.user_id 
            AND u1.has_approved_nft = true
        ), 0) as expected_level1_bonus,
        -- Level2紹介報酬
        COALESCE((
            SELECT SUM(udp2.daily_profit) * 0.10 
            FROM users u1 
            JOIN users u2 ON u2.referrer_user_id = u1.user_id 
            LEFT JOIN user_daily_profit udp2 ON u2.user_id = udp2.user_id 
            WHERE u1.referrer_user_id = u.user_id 
            AND u1.has_approved_nft = true 
            AND u2.has_approved_nft = true
        ), 0) as expected_level2_bonus,
        -- Level3紹介報酬
        COALESCE((
            SELECT SUM(udp3.daily_profit) * 0.05 
            FROM users u1 
            JOIN users u2 ON u2.referrer_user_id = u1.user_id 
            JOIN users u3 ON u3.referrer_user_id = u2.user_id 
            LEFT JOIN user_daily_profit udp3 ON u3.user_id = udp3.user_id 
            WHERE u1.referrer_user_id = u.user_id 
            AND u1.has_approved_nft = true 
            AND u2.has_approved_nft = true 
            AND u3.has_approved_nft = true
        ), 0) as expected_level3_bonus
    FROM users u
    LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
    WHERE u.has_approved_nft = true
    GROUP BY u.user_id, u.email
)
SELECT 
    '=== 全ユーザー実績と期待値比較 ===' as investigation,
    user_id,
    email,
    personal_profit,
    expected_level1_bonus,
    expected_level2_bonus,
    expected_level3_bonus,
    (personal_profit + expected_level1_bonus + expected_level2_bonus + expected_level3_bonus) as total_expected_profit,
    personal_profit as actual_profit,
    (expected_level1_bonus + expected_level2_bonus + expected_level3_bonus) as missing_referral_profit
FROM user_profits
WHERE (expected_level1_bonus + expected_level2_bonus + expected_level3_bonus) > 0
ORDER BY missing_referral_profit DESC;

-- 6. 紹介報酬処理関数の存在確認
SELECT 
    '=== 紹介報酬関数確認 ===' as investigation,
    routine_name,
    routine_type,
    CASE 
        WHEN routine_definition LIKE '%level%' OR routine_definition LIKE '%referral%' THEN '紹介報酬処理あり'
        ELSE '紹介報酬処理なし'
    END as referral_processing_status
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND (routine_name LIKE '%referral%' OR routine_name LIKE '%bonus%' OR routine_name = 'process_daily_yield_with_cycles')
ORDER BY routine_name;

-- 7. user_daily_profitテーブルの構造確認
SELECT 
    '=== user_daily_profitテーブル構造 ===' as investigation,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'user_daily_profit'
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 8. 利益処理関数の定義確認
SELECT 
    '=== 利益処理関数の定義確認 ===' as investigation,
    routine_name,
    routine_definition
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND routine_name IN ('process_daily_yield_with_cycles', 'calculate_referral_bonuses')
ORDER BY routine_name;

-- 9. システムログから紹介報酬処理の記録確認
SELECT 
    '=== 紹介報酬処理ログ確認 ===' as investigation,
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
FROM system_logs 
WHERE (message LIKE '%referral%' OR message LIKE '%bonus%' OR message LIKE '%紹介%')
ORDER BY created_at DESC
LIMIT 20;

-- 10. 月次利益取得RPC関数の確認
SELECT 
    '=== get_referral_profits関数確認 ===' as investigation,
    routine_name,
    routine_type,
    CASE 
        WHEN routine_definition IS NOT NULL THEN 'RPC関数存在'
        ELSE 'RPC関数不存在'
    END as function_status
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND routine_name = 'get_referral_profits';

-- 11. 紹介報酬が計算されていない原因の特定
SELECT 
    '=== 紹介報酬計算不具合の特定 ===' as investigation,
    CASE 
        WHEN (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'get_referral_profits') = 0 THEN 'get_referral_profits関数が存在しない'
        WHEN (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'calculate_referral_bonuses') = 0 THEN 'calculate_referral_bonuses関数が存在しない'
        WHEN (SELECT COUNT(*) FROM system_logs WHERE message LIKE '%referral%') = 0 THEN '紹介報酬処理の実行記録がない'
        ELSE '他の原因'
    END as issue_type;

-- 12. 紹介報酬を受け取るべきユーザーの統計
SELECT 
    '=== 紹介報酬対象ユーザー統計 ===' as investigation,
    COUNT(DISTINCT u0.user_id) as users_with_level1_referrals,
    COUNT(DISTINCT u1.user_id) as users_with_level2_referrals,
    COUNT(DISTINCT u2.user_id) as users_with_level3_referrals,
    SUM(COALESCE(udp1.daily_profit, 0) * 0.20) as total_missing_level1_bonus,
    SUM(COALESCE(udp2.daily_profit, 0) * 0.10) as total_missing_level2_bonus,
    SUM(COALESCE(udp3.daily_profit, 0) * 0.05) as total_missing_level3_bonus
FROM users u0
LEFT JOIN users u1 ON u1.referrer_user_id = u0.user_id
LEFT JOIN users u2 ON u2.referrer_user_id = u1.user_id
LEFT JOIN users u3 ON u3.referrer_user_id = u2.user_id
LEFT JOIN user_daily_profit udp1 ON u1.user_id = udp1.user_id
LEFT JOIN user_daily_profit udp2 ON u2.user_id = udp2.user_id
LEFT JOIN user_daily_profit udp3 ON u3.user_id = udp3.user_id
WHERE u0.has_approved_nft = true
AND (u1.has_approved_nft = true OR u2.has_approved_nft = true OR u3.has_approved_nft = true);