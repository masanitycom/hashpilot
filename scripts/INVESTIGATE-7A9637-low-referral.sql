-- ========================================
-- 7A9637の紹介報酬調査
-- ========================================

-- STEP 1: 7A9637の基本情報
SELECT 
    user_id,
    email,
    operation_start_date,
    total_nft_count,
    referrer_user_id
FROM users
WHERE user_id = '7A9637';

-- STEP 2: 7A9637の直接紹介者（Level 1）
SELECT 
    user_id,
    email,
    operation_start_date,
    has_approved_nft,
    total_nft_count
FROM users
WHERE referrer_user_id = '7A9637'
    AND has_approved_nft = true
ORDER BY user_id;

-- STEP 3: 7A9637の11月紹介報酬詳細
SELECT 
    referral_level,
    child_user_id,
    child_monthly_profit,
    profit_amount
FROM user_referral_profit_monthly
WHERE user_id = '7A9637'
    AND year = 2025
    AND month = 11
ORDER BY referral_level, child_user_id;

-- STEP 4: 7A9637の紹介報酬合計
SELECT 
    referral_level,
    COUNT(*) as count,
    SUM(child_monthly_profit) as total_child_profit,
    SUM(profit_amount) as total_referral_profit
FROM user_referral_profit_monthly
WHERE user_id = '7A9637'
    AND year = 2025
    AND month = 11
GROUP BY referral_level
ORDER BY referral_level;

-- STEP 5: 7A9637の直接紹介者の11月日利合計
SELECT 
    u.user_id,
    u.email,
    u.operation_start_date,
    u.total_nft_count,
    COALESCE(SUM(udp.daily_profit), 0) as november_profit
FROM users u
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id 
    AND udp.date >= '2025-11-01' 
    AND udp.date <= '2025-11-30'
WHERE u.referrer_user_id = '7A9637'
    AND u.has_approved_nft = true
GROUP BY u.user_id, u.email, u.operation_start_date, u.total_nft_count
ORDER BY u.user_id;

-- STEP 6: 7A9637のaffiliate_cycle状態
SELECT 
    user_id,
    available_usdt,
    cum_usdt,
    phase,
    total_nft_count
FROM affiliate_cycle
WHERE user_id = '7A9637';

