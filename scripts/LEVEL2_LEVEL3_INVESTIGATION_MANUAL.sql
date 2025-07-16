-- 🔍 Level2・Level3紹介報酬システム調査（手動実行用）
-- 2025年1月16日
-- 実行方法: Supabase SQL Editorで1つずつ実行してください

-- 1. 7A9637の紹介ツリー構造確認
-- 直接紹介者（Level1）と間接紹介者（Level2, Level3）の構造を確認
SELECT 
    '=== 7A9637の紹介ツリー構造 ===' as investigation,
    u1.user_id as level1_user,
    u1.email as level1_email,
    u2.user_id as level2_user, 
    u2.email as level2_email,
    u3.user_id as level3_user,
    u3.email as level3_email,
    u1.has_approved_nft as level1_active,
    u2.has_approved_nft as level2_active,
    u3.has_approved_nft as level3_active
FROM users u1
LEFT JOIN users u2 ON u2.referrer_user_id = u1.user_id
LEFT JOIN users u3 ON u3.referrer_user_id = u2.user_id
WHERE u1.referrer_user_id = '7A9637'
ORDER BY u1.user_id, u2.user_id, u3.user_id;

-- 2. Level1（直接紹介者）の利益記録確認
-- 7A9637が直接紹介したユーザーの利益記録を確認
SELECT 
    '=== Level1直接紹介者の利益記録 ===' as investigation,
    u.user_id,
    u.email,
    u.referrer_user_id,
    COUNT(udp.date) as profit_days,
    COALESCE(SUM(udp.daily_profit), 0) as total_profit,
    -- 7A9637が受け取るべき紹介報酬（20%）
    COALESCE(SUM(udp.daily_profit), 0) * 0.20 as expected_level1_bonus
FROM users u
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.referrer_user_id = '7A9637'
AND u.has_approved_nft = true
GROUP BY u.user_id, u.email, u.referrer_user_id
ORDER BY total_profit DESC;

-- 3. Level2（間接紹介者）の利益記録確認
-- 7A9637のLevel1が紹介したユーザーの利益記録を確認
SELECT 
    '=== Level2利益記録確認 ===' as investigation,
    u2.user_id as level2_user,
    u2.email as level2_email,
    u1.user_id as level1_referrer,
    '7A9637' as level0_referrer,
    COUNT(udp.date) as profit_days,
    COALESCE(SUM(udp.daily_profit), 0) as total_profit,
    -- 7A9637が受け取るべき紹介報酬（10%）
    COALESCE(SUM(udp.daily_profit), 0) * 0.10 as expected_level2_bonus
FROM users u1
JOIN users u2 ON u2.referrer_user_id = u1.user_id
LEFT JOIN user_daily_profit udp ON u2.user_id = udp.user_id
WHERE u1.referrer_user_id = '7A9637'
AND u2.has_approved_nft = true
GROUP BY u2.user_id, u2.email, u1.user_id
ORDER BY total_profit DESC;

-- 4. Level3（間接紹介者）の利益記録確認
-- 7A9637のLevel2が紹介したユーザーの利益記録を確認
SELECT 
    '=== Level3利益記録確認 ===' as investigation,
    u3.user_id as level3_user,
    u3.email as level3_email,
    u2.user_id as level2_referrer,
    u1.user_id as level1_referrer,
    '7A9637' as level0_referrer,
    COUNT(udp.date) as profit_days,
    COALESCE(SUM(udp.daily_profit), 0) as total_profit,
    -- 7A9637が受け取るべき紹介報酬（5%）
    COALESCE(SUM(udp.daily_profit), 0) * 0.05 as expected_level3_bonus
FROM users u1
JOIN users u2 ON u2.referrer_user_id = u1.user_id
JOIN users u3 ON u3.referrer_user_id = u2.user_id
LEFT JOIN user_daily_profit udp ON u3.user_id = udp.user_id
WHERE u1.referrer_user_id = '7A9637'
AND u3.has_approved_nft = true
GROUP BY u3.user_id, u3.email, u2.user_id, u1.user_id
ORDER BY total_profit DESC;

-- 5. 7A9637の実際の利益記録（個人分のみ）
-- 7A9637が個人NFTから受け取った利益記録を確認
SELECT 
    '=== 7A9637個人利益記録 ===' as investigation,
    date,
    daily_profit,
    yield_rate,
    user_rate,
    base_amount,
    phase,
    created_at
FROM user_daily_profit 
WHERE user_id = '7A9637'
ORDER BY date DESC;

-- 6. 7A9637の期待される総利益計算
-- 個人利益 + Level1報酬 + Level2報酬 + Level3報酬の合計
WITH referral_calculation AS (
    -- 個人利益
    SELECT 
        '7A9637' as user_id,
        'personal' as profit_type,
        0 as level,
        COALESCE(SUM(daily_profit), 0) as profit_amount
    FROM user_daily_profit 
    WHERE user_id = '7A9637'
    
    UNION ALL
    
    -- Level1紹介報酬（20%）
    SELECT 
        '7A9637' as user_id,
        'level1_referral' as profit_type,
        1 as level,
        COALESCE(SUM(udp1.daily_profit), 0) * 0.20 as profit_amount
    FROM users u1
    LEFT JOIN user_daily_profit udp1 ON u1.user_id = udp1.user_id
    WHERE u1.referrer_user_id = '7A9637'
    AND u1.has_approved_nft = true
    
    UNION ALL
    
    -- Level2紹介報酬（10%）
    SELECT 
        '7A9637' as user_id,
        'level2_referral' as profit_type,
        2 as level,
        COALESCE(SUM(udp2.daily_profit), 0) * 0.10 as profit_amount
    FROM users u1
    JOIN users u2 ON u2.referrer_user_id = u1.user_id
    LEFT JOIN user_daily_profit udp2 ON u2.user_id = udp2.user_id
    WHERE u1.referrer_user_id = '7A9637'
    AND u2.has_approved_nft = true
    
    UNION ALL
    
    -- Level3紹介報酬（5%）
    SELECT 
        '7A9637' as user_id,
        'level3_referral' as profit_type,
        3 as level,
        COALESCE(SUM(udp3.daily_profit), 0) * 0.05 as profit_amount
    FROM users u1
    JOIN users u2 ON u2.referrer_user_id = u1.user_id
    JOIN users u3 ON u3.referrer_user_id = u2.user_id
    LEFT JOIN user_daily_profit udp3 ON u3.user_id = udp3.user_id
    WHERE u1.referrer_user_id = '7A9637'
    AND u3.has_approved_nft = true
)
SELECT 
    '=== 7A9637期待利益内訳 ===' as investigation,
    profit_type,
    level,
    profit_amount,
    ROUND(profit_amount / (SELECT SUM(profit_amount) FROM referral_calculation) * 100, 2) as percentage
FROM referral_calculation
ORDER BY level;

-- 7. 7A9637の実際の利益 vs 期待利益
SELECT 
    '=== 7A9637実績と期待値比較 ===' as investigation,
    (SELECT COALESCE(SUM(daily_profit), 0) FROM user_daily_profit WHERE user_id = '7A9637') as actual_total_profit,
    (
        -- 個人利益
        (SELECT COALESCE(SUM(daily_profit), 0) FROM user_daily_profit WHERE user_id = '7A9637') +
        -- Level1報酬
        (SELECT COALESCE(SUM(udp1.daily_profit), 0) * 0.20 FROM users u1 LEFT JOIN user_daily_profit udp1 ON u1.user_id = udp1.user_id WHERE u1.referrer_user_id = '7A9637' AND u1.has_approved_nft = true) +
        -- Level2報酬
        (SELECT COALESCE(SUM(udp2.daily_profit), 0) * 0.10 FROM users u1 JOIN users u2 ON u2.referrer_user_id = u1.user_id LEFT JOIN user_daily_profit udp2 ON u2.user_id = udp2.user_id WHERE u1.referrer_user_id = '7A9637' AND u2.has_approved_nft = true) +
        -- Level3報酬
        (SELECT COALESCE(SUM(udp3.daily_profit), 0) * 0.05 FROM users u1 JOIN users u2 ON u2.referrer_user_id = u1.user_id JOIN users u3 ON u3.referrer_user_id = u2.user_id LEFT JOIN user_daily_profit udp3 ON u3.user_id = udp3.user_id WHERE u1.referrer_user_id = '7A9637' AND u3.has_approved_nft = true)
    ) as expected_total_profit;

-- 8. 紹介報酬処理関数の存在確認
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