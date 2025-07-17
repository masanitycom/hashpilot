-- ========================================
-- 紹介報酬計算のデバッグ（修正版）
-- L2が L1より高い理由を調査
-- ========================================

-- 1. Level1紹介者の確認
SELECT 
    '=== Level1紹介者の確認 ===' as check_type,
    u.user_id,
    u.has_approved_nft,
    u.created_at as user_created_at,
    p.admin_approved_at as nft_approved_at,
    p.amount_usd as investment_amount,
    ac.total_nft_count,
    COALESCE(udp.daily_profit, 0) as daily_profit_7_16,
    CASE 
        WHEN u.has_approved_nft = true AND ac.total_nft_count > 0 THEN 'ELIGIBLE'
        WHEN u.has_approved_nft = false THEN 'NFT_NOT_APPROVED'
        WHEN ac.total_nft_count = 0 THEN 'NO_NFT'
        ELSE 'UNKNOWN'
    END as eligibility_status
FROM users u
LEFT JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id AND udp.date = '2025-07-16'
WHERE u.referrer_user_id = '7A9637'
ORDER BY udp.daily_profit DESC;

-- 2. Level2紹介者の確認
SELECT 
    '=== Level2紹介者の確認 ===' as check_type,
    u2.user_id,
    u2.has_approved_nft,
    u2.created_at as user_created_at,
    p.admin_approved_at as nft_approved_at,
    p.amount_usd as investment_amount,
    ac.total_nft_count,
    COALESCE(udp.daily_profit, 0) as daily_profit_7_16,
    CASE 
        WHEN u2.has_approved_nft = true AND ac.total_nft_count > 0 THEN 'ELIGIBLE'
        WHEN u2.has_approved_nft = false THEN 'NFT_NOT_APPROVED'
        WHEN ac.total_nft_count = 0 THEN 'NO_NFT'
        ELSE 'UNKNOWN'
    END as eligibility_status
FROM users u1
JOIN users u2 ON u2.referrer_user_id = u1.user_id
LEFT JOIN purchases p ON u2.user_id = p.user_id AND p.admin_approved = true
LEFT JOIN affiliate_cycle ac ON u2.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u2.user_id = udp.user_id AND udp.date = '2025-07-16'
WHERE u1.referrer_user_id = '7A9637'
ORDER BY udp.daily_profit DESC;

-- 3. Level3紹介者の確認
SELECT 
    '=== Level3紹介者の確認 ===' as check_type,
    u3.user_id,
    u3.has_approved_nft,
    u3.created_at as user_created_at,
    p.admin_approved_at as nft_approved_at,
    p.amount_usd as investment_amount,
    ac.total_nft_count,
    COALESCE(udp.daily_profit, 0) as daily_profit_7_16,
    CASE 
        WHEN u3.has_approved_nft = true AND ac.total_nft_count > 0 THEN 'ELIGIBLE'
        WHEN u3.has_approved_nft = false THEN 'NFT_NOT_APPROVED'
        WHEN ac.total_nft_count = 0 THEN 'NO_NFT'
        ELSE 'UNKNOWN'
    END as eligibility_status
FROM users u1
JOIN users u2 ON u2.referrer_user_id = u1.user_id
JOIN users u3 ON u3.referrer_user_id = u2.user_id
LEFT JOIN purchases p ON u3.user_id = p.user_id AND p.admin_approved = true
LEFT JOIN affiliate_cycle ac ON u3.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u3.user_id = udp.user_id AND udp.date = '2025-07-16'
WHERE u1.referrer_user_id = '7A9637'
ORDER BY udp.daily_profit DESC;

-- 4. 集計データで確認
WITH referral_data AS (
    -- Level1
    SELECT 
        1 as level,
        COUNT(*) as total_users,
        COUNT(CASE WHEN u.has_approved_nft = true AND ac.total_nft_count > 0 THEN 1 END) as eligible_users,
        SUM(CASE WHEN u.has_approved_nft = true AND ac.total_nft_count > 0 THEN COALESCE(udp.daily_profit, 0) ELSE 0 END) as total_profit,
        SUM(CASE WHEN u.has_approved_nft = true AND ac.total_nft_count > 0 THEN COALESCE(udp.daily_profit, 0) ELSE 0 END) * 0.20 as referral_reward
    FROM users u
    LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id AND udp.date = '2025-07-16'
    WHERE u.referrer_user_id = '7A9637'
    
    UNION ALL
    
    -- Level2
    SELECT 
        2 as level,
        COUNT(*) as total_users,
        COUNT(CASE WHEN u2.has_approved_nft = true AND ac.total_nft_count > 0 THEN 1 END) as eligible_users,
        SUM(CASE WHEN u2.has_approved_nft = true AND ac.total_nft_count > 0 THEN COALESCE(udp.daily_profit, 0) ELSE 0 END) as total_profit,
        SUM(CASE WHEN u2.has_approved_nft = true AND ac.total_nft_count > 0 THEN COALESCE(udp.daily_profit, 0) ELSE 0 END) * 0.10 as referral_reward
    FROM users u1
    JOIN users u2 ON u2.referrer_user_id = u1.user_id
    LEFT JOIN affiliate_cycle ac ON u2.user_id = ac.user_id
    LEFT JOIN user_daily_profit udp ON u2.user_id = udp.user_id AND udp.date = '2025-07-16'
    WHERE u1.referrer_user_id = '7A9637'
    
    UNION ALL
    
    -- Level3
    SELECT 
        3 as level,
        COUNT(*) as total_users,
        COUNT(CASE WHEN u3.has_approved_nft = true AND ac.total_nft_count > 0 THEN 1 END) as eligible_users,
        SUM(CASE WHEN u3.has_approved_nft = true AND ac.total_nft_count > 0 THEN COALESCE(udp.daily_profit, 0) ELSE 0 END) as total_profit,
        SUM(CASE WHEN u3.has_approved_nft = true AND ac.total_nft_count > 0 THEN COALESCE(udp.daily_profit, 0) ELSE 0 END) * 0.05 as referral_reward
    FROM users u1
    JOIN users u2 ON u2.referrer_user_id = u1.user_id
    JOIN users u3 ON u3.referrer_user_id = u2.user_id
    LEFT JOIN affiliate_cycle ac ON u3.user_id = ac.user_id
    LEFT JOIN user_daily_profit udp ON u3.user_id = udp.user_id AND udp.date = '2025-07-16'
    WHERE u1.referrer_user_id = '7A9637'
)
SELECT 
    '=== 紹介報酬計算結果 ===' as summary,
    level,
    total_users,
    eligible_users,
    total_profit,
    referral_reward,
    CASE 
        WHEN level = 1 THEN '20%'
        WHEN level = 2 THEN '10%'
        WHEN level = 3 THEN '5%'
    END as rate
FROM referral_data
ORDER BY level;

-- 5. 運用開始日の判断基準確認
SELECT 
    '=== 運用開始日判断基準の確認 ===' as operation_start_check,
    u.user_id,
    u.has_approved_nft,
    u.created_at as user_registration,
    p.created_at as purchase_date,
    p.admin_approved_at as nft_approval_date,
    p.amount_usd,
    ac.total_nft_count,
    ac.cum_usdt,
    udp.date as profit_date,
    udp.daily_profit,
    CASE 
        WHEN u.has_approved_nft = true AND ac.total_nft_count > 0 THEN 
            CASE 
                WHEN p.admin_approved_at IS NOT NULL THEN 'APPROVED_NFT'
                WHEN p.admin_approved_at IS NULL THEN 'MANUAL_APPROVAL'
                ELSE 'UNKNOWN_APPROVAL'
            END
        ELSE 'NOT_OPERATIONAL'
    END as operation_status
FROM users u
LEFT JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id AND udp.date = '2025-07-16'
WHERE u.referrer_user_id = '7A9637'
   OR u.referrer_user_id IN (SELECT user_id FROM users WHERE referrer_user_id = '7A9637')
ORDER BY u.user_id;

-- 6. 問題の特定: なぜL2 > L1なのか
SELECT 
    '=== L2 > L1 になる理由の分析 ===' as analysis,
    'L2の紹介者がL1より多くの利益を得ている' as hypothesis_1,
    'L2の紹介者数がL1より多い' as hypothesis_2,
    'L1の一部ユーザーがNFT未承認で対象外' as hypothesis_3;

-- 7. 日利データの存在確認
SELECT 
    '=== 日利データの存在確認 ===' as profit_data_check,
    COUNT(*) as total_profit_records,
    COUNT(DISTINCT user_id) as unique_users,
    SUM(daily_profit) as total_daily_profit,
    AVG(daily_profit) as avg_daily_profit,
    MIN(daily_profit) as min_daily_profit,
    MAX(daily_profit) as max_daily_profit
FROM user_daily_profit
WHERE date = '2025-07-16';