-- ========================================
-- システム簡易チェック：11月の日利・紹介報酬 V2
-- ========================================

-- ========================================
-- PART 2: 運用開始日別の状況
-- ========================================
SELECT '========== PART 2: 運用開始日別の状況 ==========' as section;

SELECT 
    u.operation_start_date,
    COUNT(DISTINCT u.user_id) as user_count,
    COUNT(DISTINCT nm.id) as total_nfts,
    COALESCE(SUM(udp.daily_profit), 0) as total_november_profit,
    COALESCE(AVG(udp.daily_profit), 0) as avg_profit_per_user
FROM users u
LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id 
    AND udp.date >= '2025-11-01' 
    AND udp.date <= '2025-11-30'
WHERE u.has_approved_nft = true
    AND u.operation_start_date IS NOT NULL
GROUP BY u.operation_start_date
ORDER BY u.operation_start_date;

-- ========================================
-- PART 3: 11月15日運用開始ユーザー
-- ========================================
SELECT '========== PART 3: 11月15日運用開始ユーザー（サンプル20名） ==========' as section;

SELECT 
    u.user_id,
    u.email,
    u.operation_start_date,
    COUNT(DISTINCT nm.id) as nft_count,
    COUNT(DISTINCT udp.date) as days_received,
    COALESCE(SUM(udp.daily_profit), 0) as total_profit,
    ac.available_usdt,
    ac.cum_usdt
FROM users u
LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id 
    AND udp.date >= '2025-11-15' 
    AND udp.date <= '2025-11-30'
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.operation_start_date = '2025-11-15'
    AND u.has_approved_nft = true
GROUP BY u.user_id, u.email, u.operation_start_date, ac.available_usdt, ac.cum_usdt
ORDER BY u.user_id
LIMIT 20;

-- 11月15日運用開始の日利履歴（サンプル3名）
SELECT '========== 11月15日運用開始の日利履歴（サンプル3名） ==========' as section;

SELECT
    udp.user_id,
    udp.date,
    udp.daily_profit
FROM user_daily_profit udp
INNER JOIN users u ON udp.user_id = u.user_id
WHERE u.operation_start_date = '2025-11-15'
    AND udp.date >= '2025-11-15'
    AND udp.date <= '2025-11-30'
    AND u.user_id IN (
        SELECT user_id
        FROM users
        WHERE operation_start_date = '2025-11-15'
            AND has_approved_nft = true
        ORDER BY user_id
        LIMIT 3
    )
ORDER BY udp.user_id, udp.date;

-- ========================================
-- PART 4: 紹介報酬の状況
-- ========================================
SELECT '========== PART 4: 紹介報酬の状況 ==========' as section;

-- 11月の紹介報酬合計
SELECT 
    COUNT(DISTINCT user_id) as users_with_referral,
    SUM(profit_amount) as total_referral_profit,
    COUNT(*) as total_records
FROM user_referral_profit_monthly
WHERE year = 2025 AND month = 11;

-- レベル別
SELECT 
    referral_level,
    COUNT(DISTINCT user_id) as users,
    COUNT(*) as records,
    SUM(profit_amount) as total_profit
FROM user_referral_profit_monthly
WHERE year = 2025 AND month = 11
GROUP BY referral_level
ORDER BY referral_level;

-- ========================================
-- PART 5: 7A9637の詳細
-- ========================================
SELECT '========== PART 5: 7A9637の詳細 ==========' as section;

-- 基本情報
SELECT 
    u.user_id,
    u.email,
    u.operation_start_date,
    COUNT(DISTINCT nm.id) as nft_count,
    ac.available_usdt,
    ac.cum_usdt,
    ac.phase
FROM users u
LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.user_id = '7A9637'
GROUP BY u.user_id, u.email, u.operation_start_date, ac.available_usdt, ac.cum_usdt, ac.phase;

-- 11月の日利
SELECT 
    COUNT(DISTINCT date) as days,
    SUM(daily_profit) as total_personal_profit
FROM user_daily_profit
WHERE user_id = '7A9637'
    AND date >= '2025-11-01'
    AND date <= '2025-11-30';

-- 11月の紹介報酬
SELECT 
    referral_level,
    COUNT(*) as count,
    SUM(profit_amount) as total_referral
FROM user_referral_profit_monthly
WHERE user_id = '7A9637'
    AND year = 2025
    AND month = 11
GROUP BY referral_level
ORDER BY referral_level;

-- 直接紹介者
SELECT 
    u.user_id,
    u.email,
    u.operation_start_date,
    u.has_approved_nft,
    COUNT(DISTINCT nm.id) as nft_count,
    COALESCE(SUM(udp.daily_profit), 0) as nov_profit
FROM users u
LEFT JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id 
    AND udp.date >= '2025-11-01' 
    AND udp.date <= '2025-11-30'
WHERE u.referrer_user_id = '7A9637'
GROUP BY u.user_id, u.email, u.operation_start_date, u.has_approved_nft
ORDER BY u.has_approved_nft DESC, nov_profit DESC;

-- ========================================
-- PART 6: available_usdtの構成（上位20名）
-- ========================================
SELECT '========== PART 6: available_usdtの構成（上位20名） ==========' as section;

SELECT 
    ac.user_id,
    u.email,
    u.operation_start_date,
    ac.available_usdt,
    COALESCE(p.nov_personal, 0) as nov_personal,
    COALESCE(r.nov_referral, 0) as nov_referral,
    COALESCE(p.nov_personal, 0) + COALESCE(r.nov_referral, 0) as expected,
    ac.available_usdt - (COALESCE(p.nov_personal, 0) + COALESCE(r.nov_referral, 0)) as diff
FROM affiliate_cycle ac
INNER JOIN users u ON ac.user_id = u.user_id
LEFT JOIN (
    SELECT user_id, SUM(daily_profit) as nov_personal
    FROM user_daily_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30'
    GROUP BY user_id
) p ON ac.user_id = p.user_id
LEFT JOIN (
    SELECT user_id, SUM(profit_amount) as nov_referral
    FROM user_referral_profit_monthly
    WHERE year = 2025 AND month = 11
    GROUP BY user_id
) r ON ac.user_id = r.user_id
WHERE ac.available_usdt > 0
ORDER BY ac.available_usdt DESC
LIMIT 20;

SELECT '========== チェック完了 ==========' as section;

