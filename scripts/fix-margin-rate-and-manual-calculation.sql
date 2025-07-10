-- margin_rateの精度を修正し、手動で日利データを作成

-- 1. margin_rateの精度を拡張
ALTER TABLE daily_yield_log 
ALTER COLUMN margin_rate TYPE NUMERIC(10,4);

-- 2. 7/10のデータを手動で作成（関数を使わず直接作成）
DELETE FROM user_daily_profit WHERE date = '2025-07-10';
DELETE FROM daily_yield_log WHERE date = '2025-07-10';

-- 3. daily_yield_logに手動でデータ追加
INSERT INTO daily_yield_log (
    date, yield_rate, margin_rate, user_rate, is_month_end, created_at
) VALUES (
    '2025-07-10', 0.0138, 30.0, 0.005796, false, NOW()
);

-- 4. 各ユーザーの個人利益を手動計算・挿入
WITH user_calculations AS (
    SELECT 
        u.user_id,
        ac.total_nft_count,
        (ac.total_nft_count * 1000) as base_amount,
        (ac.total_nft_count * 1000 * 0.005796) as personal_profit
    FROM users u
    JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    WHERE u.total_purchases > 0
    AND ac.total_nft_count > 0
)
INSERT INTO user_daily_profit (
    user_id, date, daily_profit, yield_rate, user_rate, base_amount, 
    personal_profit, referral_profit, phase, created_at
)
SELECT 
    user_id,
    '2025-07-10'::DATE,
    personal_profit, -- 初期値は個人利益のみ
    0.0138,
    0.005796,
    base_amount,
    personal_profit,
    0, -- 紹介報酬は後で計算
    'USDT',
    NOW()
FROM user_calculations;

-- 5. 紹介報酬を手動計算して追加
-- Level1紹介報酬（20%）
UPDATE user_daily_profit 
SET 
    referral_profit = referral_profit + COALESCE((
        SELECT SUM(ref_udp.personal_profit * 0.20)
        FROM users ref_u
        JOIN user_daily_profit ref_udp ON ref_u.user_id = ref_udp.user_id 
        WHERE ref_u.referrer_user_id = user_daily_profit.user_id
        AND ref_udp.date = '2025-07-10'
    ), 0),
    daily_profit = personal_profit + referral_profit + COALESCE((
        SELECT SUM(ref_udp.personal_profit * 0.20)
        FROM users ref_u
        JOIN user_daily_profit ref_udp ON ref_u.user_id = ref_udp.user_id 
        WHERE ref_u.referrer_user_id = user_daily_profit.user_id
        AND ref_udp.date = '2025-07-10'
    ), 0)
WHERE date = '2025-07-10';

-- Level2紹介報酬（10%）
UPDATE user_daily_profit 
SET 
    referral_profit = referral_profit + COALESCE((
        SELECT SUM(ref_udp.personal_profit * 0.10)
        FROM users ref1_u
        JOIN users ref2_u ON ref2_u.referrer_user_id = ref1_u.user_id
        JOIN user_daily_profit ref_udp ON ref2_u.user_id = ref_udp.user_id 
        WHERE ref1_u.referrer_user_id = user_daily_profit.user_id
        AND ref_udp.date = '2025-07-10'
    ), 0),
    daily_profit = personal_profit + referral_profit + COALESCE((
        SELECT SUM(ref_udp.personal_profit * 0.10)
        FROM users ref1_u
        JOIN users ref2_u ON ref2_u.referrer_user_id = ref1_u.user_id
        JOIN user_daily_profit ref_udp ON ref2_u.user_id = ref_udp.user_id 
        WHERE ref1_u.referrer_user_id = user_daily_profit.user_id
        AND ref_udp.date = '2025-07-10'
    ), 0)
WHERE date = '2025-07-10';

-- Level3紹介報酬（5%）
UPDATE user_daily_profit 
SET 
    referral_profit = referral_profit + COALESCE((
        SELECT SUM(ref_udp.personal_profit * 0.05)
        FROM users ref1_u
        JOIN users ref2_u ON ref2_u.referrer_user_id = ref1_u.user_id
        JOIN users ref3_u ON ref3_u.referrer_user_id = ref2_u.user_id
        JOIN user_daily_profit ref_udp ON ref3_u.user_id = ref_udp.user_id 
        WHERE ref1_u.referrer_user_id = user_daily_profit.user_id
        AND ref_udp.date = '2025-07-10'
    ), 0),
    daily_profit = personal_profit + referral_profit + COALESCE((
        SELECT SUM(ref_udp.personal_profit * 0.05)
        FROM users ref1_u
        JOIN users ref2_u ON ref2_u.referrer_user_id = ref1_u.user_id
        JOIN users ref3_u ON ref3_u.referrer_user_id = ref2_u.user_id
        JOIN user_daily_profit ref_udp ON ref3_u.user_id = ref_udp.user_id 
        WHERE ref1_u.referrer_user_id = user_daily_profit.user_id
        AND ref_udp.date = '2025-07-10'
    ), 0)
WHERE date = '2025-07-10';

-- 6. 結果確認
SELECT '=== 手動計算後の結果確認 ===' as section;
SELECT 
    u.user_id,
    u.total_purchases,
    ac.total_nft_count,
    udp.personal_profit,
    udp.referral_profit,
    udp.daily_profit as total_profit,
    (ac.total_nft_count * 1000 * 0.005796) as expected_personal_profit
FROM users u
JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id AND udp.date = '2025-07-10'
WHERE u.user_id IN ('2BF53B', '9DCFD1', 'B43A3D')
ORDER BY u.total_purchases DESC;

-- 7. 統計確認
SELECT '=== 全体統計 ===' as section;
SELECT 
    COUNT(*) as users,
    SUM(personal_profit) as total_personal,
    SUM(referral_profit) as total_referral,
    SUM(daily_profit) as total_profit,
    AVG(daily_profit) as avg_profit
FROM user_daily_profit 
WHERE date = '2025-07-10';

SELECT 'margin_rateを修正し、手動で正しい日利データを作成しました' as message;