-- ========================================
-- 紹介報酬計算のデバッグ
-- L2が L1より高い理由を調査
-- ========================================

-- 特定のユーザーID（例：7A9637）の紹介ツリーを確認
-- 実際のユーザーIDに置き換えてください
DO $$
DECLARE
    target_user_id TEXT := '7A9637';  -- 実際のユーザーIDに変更
    target_date DATE := '2025-07-16';  -- 昨日の日付に変更
BEGIN
    -- 1. Level1紹介者の確認
    RAISE NOTICE '=== Level1紹介者の確認 ===';
    FOR rec IN 
        SELECT u.user_id, u.has_approved_nft, COALESCE(udp.daily_profit, 0) as daily_profit
        FROM users u
        LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id AND udp.date = target_date
        WHERE u.referrer_user_id = target_user_id
    LOOP
        RAISE NOTICE 'L1: % (NFT承認: %, 利益: $%)', rec.user_id, rec.has_approved_nft, rec.daily_profit;
    END LOOP;
    
    -- 2. Level2紹介者の確認
    RAISE NOTICE '=== Level2紹介者の確認 ===';
    FOR rec IN 
        SELECT u2.user_id, u2.has_approved_nft, COALESCE(udp.daily_profit, 0) as daily_profit
        FROM users u1
        JOIN users u2 ON u2.referrer_user_id = u1.user_id
        LEFT JOIN user_daily_profit udp ON u2.user_id = udp.user_id AND udp.date = target_date
        WHERE u1.referrer_user_id = target_user_id
    LOOP
        RAISE NOTICE 'L2: % (NFT承認: %, 利益: $%)', rec.user_id, rec.has_approved_nft, rec.daily_profit;
    END LOOP;
    
    -- 3. Level3紹介者の確認
    RAISE NOTICE '=== Level3紹介者の確認 ===';
    FOR rec IN 
        SELECT u3.user_id, u3.has_approved_nft, COALESCE(udp.daily_profit, 0) as daily_profit
        FROM users u1
        JOIN users u2 ON u2.referrer_user_id = u1.user_id
        JOIN users u3 ON u3.referrer_user_id = u2.user_id
        LEFT JOIN user_daily_profit udp ON u3.user_id = udp.user_id AND udp.date = target_date
        WHERE u1.referrer_user_id = target_user_id
    LOOP
        RAISE NOTICE 'L3: % (NFT承認: %, 利益: $%)', rec.user_id, rec.has_approved_nft, rec.daily_profit;
    END LOOP;
END $$;

-- 4. 集計データで確認
WITH referral_data AS (
    -- Level1
    SELECT 
        1 as level,
        COUNT(*) as user_count,
        SUM(CASE WHEN u.has_approved_nft = true THEN COALESCE(udp.daily_profit, 0) ELSE 0 END) as total_profit,
        SUM(CASE WHEN u.has_approved_nft = true THEN COALESCE(udp.daily_profit, 0) ELSE 0 END) * 0.20 as referral_reward
    FROM users u
    LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id AND udp.date = '2025-07-16'
    WHERE u.referrer_user_id = '7A9637'
    
    UNION ALL
    
    -- Level2
    SELECT 
        2 as level,
        COUNT(*) as user_count,
        SUM(CASE WHEN u2.has_approved_nft = true THEN COALESCE(udp.daily_profit, 0) ELSE 0 END) as total_profit,
        SUM(CASE WHEN u2.has_approved_nft = true THEN COALESCE(udp.daily_profit, 0) ELSE 0 END) * 0.10 as referral_reward
    FROM users u1
    JOIN users u2 ON u2.referrer_user_id = u1.user_id
    LEFT JOIN user_daily_profit udp ON u2.user_id = udp.user_id AND udp.date = '2025-07-16'
    WHERE u1.referrer_user_id = '7A9637'
    
    UNION ALL
    
    -- Level3
    SELECT 
        3 as level,
        COUNT(*) as user_count,
        SUM(CASE WHEN u3.has_approved_nft = true THEN COALESCE(udp.daily_profit, 0) ELSE 0 END) as total_profit,
        SUM(CASE WHEN u3.has_approved_nft = true THEN COALESCE(udp.daily_profit, 0) ELSE 0 END) * 0.05 as referral_reward
    FROM users u1
    JOIN users u2 ON u2.referrer_user_id = u1.user_id
    JOIN users u3 ON u3.referrer_user_id = u2.user_id
    LEFT JOIN user_daily_profit udp ON u3.user_id = udp.user_id AND udp.date = '2025-07-16'
    WHERE u1.referrer_user_id = '7A9637'
)
SELECT 
    '=== 紹介報酬計算結果 ===' as summary,
    level,
    user_count,
    total_profit,
    referral_reward,
    CASE 
        WHEN level = 1 THEN '20%'
        WHEN level = 2 THEN '10%'
        WHEN level = 3 THEN '5%'
    END as rate
FROM referral_data
ORDER BY level;

-- 5. 問題の原因を特定するための詳細分析
SELECT 
    '=== 問題の原因分析 ===' as analysis,
    'L2の紹介者がL1より多くの利益を得ている可能性' as hypothesis;

-- 6. 実際のユーザーの投資額と利益の関係を確認
SELECT 
    '=== ユーザーの投資額と利益の関係 ===' as investment_analysis,
    u.user_id,
    ac.total_nft_count,
    ac.total_nft_count * 1100 as investment_amount,
    udp.daily_profit,
    CASE 
        WHEN u.referrer_user_id = '7A9637' THEN 'L1'
        WHEN u.referrer_user_id IN (SELECT user_id FROM users WHERE referrer_user_id = '7A9637') THEN 'L2'
        ELSE 'Other'
    END as referral_level
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id AND udp.date = '2025-07-16'
WHERE (u.referrer_user_id = '7A9637' 
    OR u.referrer_user_id IN (SELECT user_id FROM users WHERE referrer_user_id = '7A9637'))
    AND u.has_approved_nft = true
ORDER BY udp.daily_profit DESC;