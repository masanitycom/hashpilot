-- ========================================
-- システム全体チェック：11月の日利・紹介報酬の整合性確認
-- ========================================

-- ========================================
-- PART 1: 日利処理の実行状況
-- ========================================
\echo '========================================';
\echo 'PART 1: 日利処理の実行状況';
\echo '========================================';

-- 11月の日利設定日を確認
SELECT 
    date,
    yield_rate,
    margin_rate,
    created_at
FROM daily_yield_settings
WHERE date >= '2025-11-01' AND date <= '2025-11-30'
ORDER BY date;

-- 11月の日利配布日数を確認
SELECT 
    COUNT(DISTINCT date) as days_with_profit,
    MIN(date) as first_date,
    MAX(date) as last_date,
    COUNT(DISTINCT user_id) as total_users
FROM user_daily_profit
WHERE date >= '2025-11-01' AND date <= '2025-11-30';

-- ========================================
-- PART 2: 運用開始日別のユーザー数と日利合計
-- ========================================
\echo '';
\echo '========================================';
\echo 'PART 2: 運用開始日別のユーザー数と日利合計';
\echo '========================================';

SELECT 
    u.operation_start_date,
    COUNT(DISTINCT u.user_id) as user_count,
    SUM(u.total_nft_count) as total_nfts,
    COUNT(DISTINCT udp.date) as days_with_profit,
    COALESCE(SUM(udp.daily_profit), 0) as total_november_profit,
    COALESCE(AVG(udp.daily_profit), 0) as avg_daily_profit_per_user
FROM users u
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id 
    AND udp.date >= '2025-11-01' 
    AND udp.date <= '2025-11-30'
WHERE u.has_approved_nft = true
    AND u.operation_start_date IS NOT NULL
GROUP BY u.operation_start_date
ORDER BY u.operation_start_date;

-- ========================================
-- PART 3: 11月15日運用開始ユーザーの詳細
-- ========================================
\echo '';
\echo '========================================';
\echo 'PART 3: 11月15日運用開始ユーザーの詳細';
\echo '========================================';

-- 11月15日運用開始のユーザー一覧
SELECT 
    u.user_id,
    u.email,
    u.operation_start_date,
    u.total_nft_count,
    COUNT(DISTINCT udp.date) as days_with_profit,
    COALESCE(SUM(udp.daily_profit), 0) as total_november_profit,
    ac.available_usdt,
    ac.cum_usdt
FROM users u
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id 
    AND udp.date >= '2025-11-01' 
    AND udp.date <= '2025-11-30'
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.operation_start_date = '2025-11-15'
    AND u.has_approved_nft = true
GROUP BY u.user_id, u.email, u.operation_start_date, u.total_nft_count, ac.available_usdt, ac.cum_usdt
ORDER BY u.user_id
LIMIT 20;

-- 11月15日運用開始ユーザーの具体的な日利履歴（サンプル3名）
SELECT 
    udp.user_id,
    u.email,
    udp.date,
    udp.daily_profit,
    udp.nft_count
FROM user_daily_profit udp
INNER JOIN users u ON udp.user_id = u.user_id
WHERE u.operation_start_date = '2025-11-15'
    AND udp.date >= '2025-11-15'
    AND udp.date <= '2025-11-30'
    AND u.user_id IN (
        SELECT user_id 
        FROM users 
        WHERE operation_start_date = '2025-11-15' 
        LIMIT 3
    )
ORDER BY udp.user_id, udp.date;

-- ========================================
-- PART 4: 紹介報酬の整合性チェック
-- ========================================
\echo '';
\echo '========================================';
\echo 'PART 4: 紹介報酬の整合性チェック';
\echo '========================================';

-- 11月の紹介報酬合計
SELECT 
    COUNT(DISTINCT user_id) as users_with_referral,
    SUM(profit_amount) as total_referral_profit,
    COUNT(*) as total_records
FROM user_referral_profit_monthly
WHERE year = 2025 AND month = 11;

-- レベル別の紹介報酬
SELECT 
    referral_level,
    COUNT(DISTINCT user_id) as users,
    COUNT(*) as records,
    SUM(child_monthly_profit) as total_child_profit,
    SUM(profit_amount) as total_referral_profit,
    AVG(profit_amount) as avg_referral_profit
FROM user_referral_profit_monthly
WHERE year = 2025 AND month = 11
GROUP BY referral_level
ORDER BY referral_level;

-- ========================================
-- PART 5: 7A9637の詳細調査
-- ========================================
\echo '';
\echo '========================================';
\echo 'PART 5: 7A9637の詳細調査';
\echo '========================================';

-- 7A9637の基本情報
SELECT 
    u.user_id,
    u.email,
    u.operation_start_date,
    u.total_nft_count,
    ac.available_usdt,
    ac.cum_usdt,
    ac.phase
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.user_id = '7A9637';

-- 7A9637の11月日利合計
SELECT 
    COUNT(DISTINCT date) as days_with_profit,
    SUM(daily_profit) as total_personal_profit
FROM user_daily_profit
WHERE user_id = '7A9637'
    AND date >= '2025-11-01'
    AND date <= '2025-11-30';

-- 7A9637の11月紹介報酬
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

-- 7A9637の直接紹介者（Level 1）
SELECT 
    u.user_id,
    u.email,
    u.operation_start_date,
    u.has_approved_nft,
    u.total_nft_count,
    COALESCE(SUM(udp.daily_profit), 0) as november_profit
FROM users u
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id 
    AND udp.date >= '2025-11-01' 
    AND udp.date <= '2025-11-30'
WHERE u.referrer_user_id = '7A9637'
GROUP BY u.user_id, u.email, u.operation_start_date, u.has_approved_nft, u.total_nft_count
ORDER BY u.has_approved_nft DESC, u.user_id;

-- ========================================
-- PART 6: affiliate_cycleとuser_referral_profit_monthlyの整合性
-- ========================================
\echo '';
\echo '========================================';
\echo 'PART 6: affiliate_cycleとuser_referral_profit_monthlyの整合性';
\echo '========================================';

-- cum_usdtと11月紹介報酬の比較（上位20名）
SELECT 
    ac.user_id,
    u.email,
    ac.cum_usdt as cycle_cum_usdt,
    COALESCE(urpm.november_referral, 0) as november_referral,
    ac.cum_usdt - COALESCE(urpm.november_referral, 0) as difference
FROM affiliate_cycle ac
INNER JOIN users u ON ac.user_id = u.user_id
LEFT JOIN (
    SELECT user_id, SUM(profit_amount) as november_referral
    FROM user_referral_profit_monthly
    WHERE year = 2025 AND month = 11
    GROUP BY user_id
) urpm ON ac.user_id = urpm.user_id
WHERE ac.cum_usdt > 0 OR urpm.november_referral > 0
ORDER BY ac.cum_usdt DESC
LIMIT 20;

-- ========================================
-- PART 7: available_usdtの構成要素確認
-- ========================================
\echo '';
\echo '========================================';
\echo 'PART 7: available_usdtの構成要素確認（サンプル20名）';
\echo '========================================';

SELECT 
    ac.user_id,
    u.email,
    u.operation_start_date,
    ac.available_usdt,
    COALESCE(personal.november_personal, 0) as november_personal_profit,
    COALESCE(referral.november_referral, 0) as november_referral_profit,
    COALESCE(personal.november_personal, 0) + COALESCE(referral.november_referral, 0) as expected_total,
    ac.available_usdt - (COALESCE(personal.november_personal, 0) + COALESCE(referral.november_referral, 0)) as difference
FROM affiliate_cycle ac
INNER JOIN users u ON ac.user_id = u.user_id
LEFT JOIN (
    SELECT user_id, SUM(daily_profit) as november_personal
    FROM user_daily_profit
    WHERE date >= '2025-11-01' AND date <= '2025-11-30'
    GROUP BY user_id
) personal ON ac.user_id = personal.user_id
LEFT JOIN (
    SELECT user_id, SUM(profit_amount) as november_referral
    FROM user_referral_profit_monthly
    WHERE year = 2025 AND month = 11
    GROUP BY user_id
) referral ON ac.user_id = referral.user_id
WHERE ac.available_usdt > 0
ORDER BY ac.available_usdt DESC
LIMIT 20;

\echo '';
\echo '========================================';
\echo 'チェック完了';
\echo '========================================';

