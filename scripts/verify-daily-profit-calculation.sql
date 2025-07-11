-- 日利計算の正確性を検証するスクリプト

-- 1. 現在の日利設定の確認
SELECT '=== 現在の日利設定 ===' as section;
SELECT 
    date,
    yield_rate,
    margin_rate,
    user_rate,
    is_month_end,
    -- 手動計算での検証
    yield_rate * (1 - margin_rate/100) as calculated_after_margin,
    yield_rate * (1 - margin_rate/100) * 0.6 as calculated_user_rate,
    -- 期待値との比較
    CASE 
        WHEN abs(user_rate - (yield_rate * (1 - margin_rate/100) * 0.6)) < 0.000001 
        THEN 'OK' 
        ELSE 'MISMATCH' 
    END as calculation_status
FROM daily_yield_log 
WHERE date = '2025-07-10';

-- 2. ユーザー別計算の検証
SELECT '=== ユーザー別計算検証 ===' as section;
WITH expected_calculations AS (
    SELECT 
        u.user_id,
        u.email,
        u.total_purchases,
        ac.total_nft_count,
        -- 期待値計算
        ac.total_nft_count * 1000 as expected_base_amount,
        ac.total_nft_count * 1000 * 0.005796 as expected_personal_profit,
        -- 紹介報酬の期待値
        COALESCE((
            SELECT SUM(ref_ac.total_nft_count * 1000 * 0.005796 * 0.20)
            FROM users ref_u
            JOIN affiliate_cycle ref_ac ON ref_u.user_id = ref_ac.user_id
            WHERE ref_u.referrer_user_id = u.user_id
            AND ref_ac.total_nft_count > 0
        ), 0) as expected_level1_bonus,
        COALESCE((
            SELECT SUM(ref_ac.total_nft_count * 1000 * 0.005796 * 0.10)
            FROM users ref1_u
            JOIN users ref2_u ON ref2_u.referrer_user_id = ref1_u.user_id
            JOIN affiliate_cycle ref_ac ON ref2_u.user_id = ref_ac.user_id
            WHERE ref1_u.referrer_user_id = u.user_id
            AND ref_ac.total_nft_count > 0
        ), 0) as expected_level2_bonus,
        COALESCE((
            SELECT SUM(ref_ac.total_nft_count * 1000 * 0.005796 * 0.05)
            FROM users ref1_u
            JOIN users ref2_u ON ref2_u.referrer_user_id = ref1_u.user_id
            JOIN users ref3_u ON ref3_u.referrer_user_id = ref2_u.user_id
            JOIN affiliate_cycle ref_ac ON ref3_u.user_id = ref_ac.user_id
            WHERE ref1_u.referrer_user_id = u.user_id
            AND ref_ac.total_nft_count > 0
        ), 0) as expected_level3_bonus
    FROM users u
    JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE u.total_purchases > 0 
    AND ac.total_nft_count > 0
)
SELECT 
    ec.user_id,
    ec.email,
    ec.total_purchases,
    ec.total_nft_count,
    -- 期待値
    ec.expected_base_amount,
    ec.expected_personal_profit,
    (ec.expected_level1_bonus + ec.expected_level2_bonus + ec.expected_level3_bonus) as expected_total_referral,
    (ec.expected_personal_profit + ec.expected_level1_bonus + ec.expected_level2_bonus + ec.expected_level3_bonus) as expected_total_profit,
    -- 実際の値
    udp.base_amount as actual_base_amount,
    udp.personal_profit as actual_personal_profit,
    udp.referral_profit as actual_referral_profit,
    udp.daily_profit as actual_total_profit,
    -- 差異チェック
    CASE 
        WHEN abs(udp.personal_profit - ec.expected_personal_profit) < 0.01 
        THEN 'OK' 
        ELSE 'MISMATCH' 
    END as personal_profit_status,
    CASE 
        WHEN abs(udp.referral_profit - (ec.expected_level1_bonus + ec.expected_level2_bonus + ec.expected_level3_bonus)) < 0.01 
        THEN 'OK' 
        ELSE 'MISMATCH' 
    END as referral_profit_status
FROM expected_calculations ec
LEFT JOIN user_daily_profit udp ON ec.user_id = udp.user_id AND udp.date = '2025-07-10'
ORDER BY ec.total_purchases DESC
LIMIT 10;

-- 3. 紹介報酬の詳細検証
SELECT '=== 紹介報酬詳細検証 ===' as section;
WITH referral_details AS (
    SELECT 
        u.user_id,
        u.email,
        -- Level1 紹介者
        (SELECT COUNT(*) FROM users ref WHERE ref.referrer_user_id = u.user_id) as level1_count,
        COALESCE((
            SELECT SUM(ref_ac.total_nft_count * 1000 * 0.005796 * 0.20)
            FROM users ref_u
            JOIN affiliate_cycle ref_ac ON ref_u.user_id = ref_ac.user_id
            WHERE ref_u.referrer_user_id = u.user_id
            AND ref_ac.total_nft_count > 0
        ), 0) as level1_bonus,
        -- Level2 紹介者
        (SELECT COUNT(*) 
         FROM users ref1 
         JOIN users ref2 ON ref2.referrer_user_id = ref1.user_id
         WHERE ref1.referrer_user_id = u.user_id) as level2_count,
        COALESCE((
            SELECT SUM(ref_ac.total_nft_count * 1000 * 0.005796 * 0.10)
            FROM users ref1_u
            JOIN users ref2_u ON ref2_u.referrer_user_id = ref1_u.user_id
            JOIN affiliate_cycle ref_ac ON ref2_u.user_id = ref_ac.user_id
            WHERE ref1_u.referrer_user_id = u.user_id
            AND ref_ac.total_nft_count > 0
        ), 0) as level2_bonus,
        -- Level3 紹介者
        (SELECT COUNT(*) 
         FROM users ref1 
         JOIN users ref2 ON ref2.referrer_user_id = ref1.user_id
         JOIN users ref3 ON ref3.referrer_user_id = ref2.user_id
         WHERE ref1.referrer_user_id = u.user_id) as level3_count,
        COALESCE((
            SELECT SUM(ref_ac.total_nft_count * 1000 * 0.005796 * 0.05)
            FROM users ref1_u
            JOIN users ref2_u ON ref2_u.referrer_user_id = ref1_u.user_id
            JOIN users ref3_u ON ref3_u.referrer_user_id = ref2_u.user_id
            JOIN affiliate_cycle ref_ac ON ref3_u.user_id = ref_ac.user_id
            WHERE ref1_u.referrer_user_id = u.user_id
            AND ref_ac.total_nft_count > 0
        ), 0) as level3_bonus
    FROM users u
    WHERE u.total_purchases > 0
)
SELECT 
    rd.user_id,
    rd.email,
    rd.level1_count,
    rd.level1_bonus,
    rd.level2_count,
    rd.level2_bonus,
    rd.level3_count,
    rd.level3_bonus,
    (rd.level1_bonus + rd.level2_bonus + rd.level3_bonus) as total_expected_referral,
    udp.referral_profit as actual_referral_profit,
    CASE 
        WHEN abs(udp.referral_profit - (rd.level1_bonus + rd.level2_bonus + rd.level3_bonus)) < 0.01 
        THEN 'OK' 
        ELSE 'MISMATCH' 
    END as referral_status
FROM referral_details rd
LEFT JOIN user_daily_profit udp ON rd.user_id = udp.user_id AND udp.date = '2025-07-10'
WHERE (rd.level1_count > 0 OR rd.level2_count > 0 OR rd.level3_count > 0)
ORDER BY (rd.level1_bonus + rd.level2_bonus + rd.level3_bonus) DESC
LIMIT 10;

-- 4. 全体統計の検証
SELECT '=== 全体統計検証 ===' as section;
SELECT 
    COUNT(*) as total_users_with_profit,
    SUM(personal_profit) as total_personal_profit,
    SUM(referral_profit) as total_referral_profit,
    SUM(daily_profit) as total_daily_profit,
    AVG(daily_profit) as average_daily_profit,
    MIN(daily_profit) as min_daily_profit,
    MAX(daily_profit) as max_daily_profit,
    -- 計算の整合性チェック
    CASE 
        WHEN abs(SUM(daily_profit) - (SUM(personal_profit) + SUM(referral_profit))) < 0.01 
        THEN 'OK' 
        ELSE 'MISMATCH' 
    END as total_calculation_status
FROM user_daily_profit 
WHERE date = '2025-07-10';

-- 5. 月末処理の検証
SELECT '=== 月末処理検証 ===' as section;
SELECT 
    'Month-end processing verification' as description,
    CASE 
        WHEN EXISTS (SELECT 1 FROM daily_yield_log WHERE date = '2025-07-10' AND is_month_end = true)
        THEN 'Month-end bonus applied'
        ELSE 'Regular processing'
    END as month_end_status,
    CASE 
        WHEN EXISTS (SELECT 1 FROM daily_yield_log WHERE date = '2025-07-10' AND is_month_end = true)
        THEN 'User rate should include 5% bonus'
        ELSE 'User rate is normal calculation'
    END as bonus_note;

SELECT 'Daily profit calculation verification completed' as message;