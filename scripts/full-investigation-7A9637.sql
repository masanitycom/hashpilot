-- 7A9637の完全調査：表示と実データの矛盾を解明

SELECT '=== 1. 7A9637の全データ ===' as section;

SELECT * FROM users WHERE user_id = '7A9637';
SELECT * FROM affiliate_cycle WHERE user_id = '7A9637';

-- SELECT '=== 2. 7A9637の出金履歴 ===' as section;
-- withdrawalsテーブルが存在しないためスキップ

SELECT '=== 3. 7A9637の全紹介者 ===' as section;

SELECT
    user_id,
    email,
    has_approved_nft,
    total_purchases,
    created_at
FROM users
WHERE referrer_user_id = '7A9637'
ORDER BY created_at;

SELECT '=== 4. 各紹介者のaffiliate_cycle ===' as section;

SELECT
    ac.user_id,
    u.email,
    ac.total_nft_count,
    ac.phase,
    ac.cum_usdt,
    ac.available_usdt
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
WHERE u.referrer_user_id = '7A9637';

SELECT '=== 5. 各紹介者の日次利益（今月分） ===' as section;

SELECT
    udp.user_id,
    u.email,
    COUNT(*) as days_count,
    SUM(udp.daily_profit) as total_profit
FROM user_daily_profit udp
JOIN users u ON udp.user_id = u.user_id
WHERE u.referrer_user_id = '7A9637'
  AND udp.date >= DATE_TRUNC('month', CURRENT_DATE)
GROUP BY udp.user_id, u.email
ORDER BY total_profit DESC;

SELECT '=== 6. 7A9637の日次利益履歴（最新30件） ===' as section;

SELECT
    date,
    daily_profit,
    base_amount,
    phase
FROM user_daily_profit
WHERE user_id = '7A9637'
ORDER BY date DESC
LIMIT 30;

SELECT '=== 7. 7A9637の今月の紹介報酬（詳細計算） ===' as section;

-- Level 1紹介者の今月の利益
WITH level1_users AS (
    SELECT user_id
    FROM users
    WHERE referrer_user_id = '7A9637'
      AND has_approved_nft = true
),
level1_profits AS (
    SELECT
        udp.user_id,
        u.email,
        SUM(udp.daily_profit) as total_profit,
        SUM(udp.daily_profit) * 0.20 as referral_reward
    FROM user_daily_profit udp
    JOIN users u ON udp.user_id = u.user_id
    WHERE udp.user_id IN (SELECT user_id FROM level1_users)
      AND udp.date >= DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY udp.user_id, u.email
)
SELECT
    user_id,
    email,
    total_profit,
    referral_reward
FROM level1_profits
ORDER BY referral_reward DESC;

-- 合計
SELECT
    SUM(udp.daily_profit) as level1_total_profit,
    SUM(udp.daily_profit) * 0.20 as expected_referral_reward
FROM user_daily_profit udp
WHERE udp.user_id IN (
    SELECT user_id FROM users
    WHERE referrer_user_id = '7A9637'
      AND has_approved_nft = true
)
AND udp.date >= DATE_TRUNC('month', CURRENT_DATE);

SELECT '=== 8. 7E0A1Eの状況確認 ===' as section;

SELECT
    u.user_id,
    u.email,
    u.has_approved_nft,
    u.total_purchases,
    ac.total_nft_count,
    ac.phase
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
WHERE u.user_id = '7E0A1E';

-- 7E0A1Eの日次利益
SELECT
    date,
    daily_profit,
    base_amount
FROM user_daily_profit
WHERE user_id = '7E0A1E'
ORDER BY date DESC
LIMIT 10;

SELECT '=== 9. NFTサイクル計算の検証 ===' as section;

-- cum_usdtがどこから来ているか
SELECT
    'affiliate_cycle.cum_usdt' as source,
    cum_usdt as value
FROM affiliate_cycle
WHERE user_id = '7A9637'

UNION ALL

SELECT
    '今月の紹介報酬合計' as source,
    COALESCE(SUM(udp.daily_profit) * 0.20, 0) as value
FROM user_daily_profit udp
WHERE udp.user_id IN (
    SELECT user_id FROM users
    WHERE referrer_user_id = '7A9637'
      AND has_approved_nft = true
)
AND udp.date >= DATE_TRUNC('month', CURRENT_DATE);
