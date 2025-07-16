-- 🔍 Level2・Level3紹介報酬システム徹底調査
-- 2025年1月16日

-- 1. 紹介ツリー構造の確認（7A9637を起点）
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

-- 2. 各レベルの利益記録確認
SELECT 
    '=== Level別利益記録確認 ===' as investigation,
    'Level1直接紹介者の利益記録' as check_type,
    u.user_id,
    u.email,
    u.referrer_user_id,
    COUNT(udp.date) as profit_days,
    COALESCE(SUM(udp.daily_profit), 0) as total_profit
FROM users u
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.referrer_user_id = '7A9637'
AND u.has_approved_nft = true
GROUP BY u.user_id, u.email, u.referrer_user_id
ORDER BY total_profit DESC;

-- 3. Level2ユーザーの利益記録
SELECT 
    '=== Level2利益記録確認 ===' as investigation,
    u2.user_id as level2_user,
    u2.email as level2_email,
    u1.user_id as level1_referrer,
    '7A9637' as level0_referrer,
    COUNT(udp.date) as profit_days,
    COALESCE(SUM(udp.daily_profit), 0) as total_profit
FROM users u1
JOIN users u2 ON u2.referrer_user_id = u1.user_id
LEFT JOIN user_daily_profit udp ON u2.user_id = udp.user_id
WHERE u1.referrer_user_id = '7A9637'
AND u2.has_approved_nft = true
GROUP BY u2.user_id, u2.email, u1.user_id
ORDER BY total_profit DESC;

-- 4. Level3ユーザーの利益記録
SELECT 
    '=== Level3利益記録確認 ===' as investigation,
    u3.user_id as level3_user,
    u3.email as level3_email,
    u2.user_id as level2_referrer,
    u1.user_id as level1_referrer,
    '7A9637' as level0_referrer,
    COUNT(udp.date) as profit_days,
    COALESCE(SUM(udp.daily_profit), 0) as total_profit
FROM users u1
JOIN users u2 ON u2.referrer_user_id = u1.user_id
JOIN users u3 ON u3.referrer_user_id = u2.user_id
LEFT JOIN user_daily_profit udp ON u3.user_id = udp.user_id
WHERE u1.referrer_user_id = '7A9637'
AND u3.has_approved_nft = true
GROUP BY u3.user_id, u3.email, u2.user_id, u1.user_id
ORDER BY total_profit DESC;

-- 5. 紹介報酬関数の存在確認
SELECT 
    '=== 紹介報酬関数確認 ===' as investigation,
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND (routine_name LIKE '%referral%' OR routine_name LIKE '%bonus%')
ORDER BY routine_name;

-- 6. user_daily_profitテーブルの構造確認
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

-- 7. 実際の日利処理で紹介報酬が計算されているかチェック
SELECT 
    '=== 7A9637の紹介報酬受取記録 ===' as investigation,
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

-- 8. 利益処理関数の中身確認
SELECT 
    '=== 利益処理関数の定義確認 ===' as investigation,
    routine_name,
    routine_definition
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND routine_name IN ('process_daily_yield_with_cycles', 'calculate_referral_bonuses')
ORDER BY routine_name;

-- 9. system_logsから紹介報酬処理の記録確認
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

-- 10. 7A9637の期待される紹介報酬計算
WITH referral_calculation AS (
    -- Level1の紹介者とその利益
    SELECT 
        '7A9637' as beneficiary,
        1 as level,
        u1.user_id as referral_user,
        COALESCE(SUM(udp1.daily_profit), 0) as referral_total_profit,
        COALESCE(SUM(udp1.daily_profit), 0) * 0.20 as expected_bonus_20pct
    FROM users u1
    LEFT JOIN user_daily_profit udp1 ON u1.user_id = udp1.user_id
    WHERE u1.referrer_user_id = '7A9637'
    AND u1.has_approved_nft = true
    GROUP BY u1.user_id
    
    UNION ALL
    
    -- Level2の紹介者とその利益
    SELECT 
        '7A9637' as beneficiary,
        2 as level,
        u2.user_id as referral_user,
        COALESCE(SUM(udp2.daily_profit), 0) as referral_total_profit,
        COALESCE(SUM(udp2.daily_profit), 0) * 0.10 as expected_bonus_10pct
    FROM users u1
    JOIN users u2 ON u2.referrer_user_id = u1.user_id
    LEFT JOIN user_daily_profit udp2 ON u2.user_id = udp2.user_id
    WHERE u1.referrer_user_id = '7A9637'
    AND u2.has_approved_nft = true
    GROUP BY u2.user_id
    
    UNION ALL
    
    -- Level3の紹介者とその利益
    SELECT 
        '7A9637' as beneficiary,
        3 as level,
        u3.user_id as referral_user,
        COALESCE(SUM(udp3.daily_profit), 0) as referral_total_profit,
        COALESCE(SUM(udp3.daily_profit), 0) * 0.05 as expected_bonus_5pct
    FROM users u1
    JOIN users u2 ON u2.referrer_user_id = u1.user_id
    JOIN users u3 ON u3.referrer_user_id = u2.user_id
    LEFT JOIN user_daily_profit udp3 ON u3.user_id = udp3.user_id
    WHERE u1.referrer_user_id = '7A9637'
    AND u3.has_approved_nft = true
    GROUP BY u3.user_id
)
SELECT 
    '=== 7A9637期待紹介報酬計算 ===' as investigation,
    level,
    COUNT(*) as referral_count,
    SUM(referral_total_profit) as total_referral_profit,
    SUM(expected_bonus_20pct) as total_expected_bonus,
    CASE 
        WHEN level = 1 THEN '20%'
        WHEN level = 2 THEN '10%'
        WHEN level = 3 THEN '5%'
    END as bonus_rate
FROM referral_calculation
GROUP BY level
ORDER BY level;

-- 11. 現在の7A9637の実際の受取利益と期待値の比較
SELECT 
    '=== 7A9637実績と期待値比較 ===' as investigation,
    (SELECT COALESCE(SUM(daily_profit), 0) FROM user_daily_profit WHERE user_id = '7A9637') as actual_total_profit,
    '予想: 個人利益 + Level1紹介報酬 + Level2紹介報酬 + Level3紹介報酬' as expected_components;

-- 12. 日利処理関数が実際に紹介報酬を計算しているかチェック
SELECT 
    '=== 関数内紹介報酬処理チェック ===' as investigation,
    routine_name,
    CASE 
        WHEN routine_definition LIKE '%level%' OR routine_definition LIKE '%referral%' THEN '紹介報酬処理あり'
        ELSE '紹介報酬処理なし'
    END as referral_processing_status
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND routine_name = 'process_daily_yield_with_cycles';