-- ========================================
-- 紹介報酬が0になっている原因を調査
-- ========================================

SELECT '=== 1. 運用開始済みユーザーの確認 ===' as section;

SELECT
    u.user_id,
    u.email,
    u.referrer_user_id,
    u.operation_start_date,
    ac.total_nft_count
FROM users u
LEFT JOIN affiliate_cycle ac ON ac.user_id = u.user_id
WHERE u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= CURRENT_DATE
ORDER BY u.operation_start_date;

SELECT '=== 2. 7E0A1Eの直接紹介者（Level 1）で運用開始済み ===' as section;

SELECT
    u.user_id,
    u.email,
    u.operation_start_date,
    ac.total_nft_count,
    ac.cum_usdt,
    CASE
        WHEN u.operation_start_date <= CURRENT_DATE THEN '✅ 運用開始済み'
        ELSE '⏳ 運用開始前'
    END as status
FROM users u
LEFT JOIN affiliate_cycle ac ON ac.user_id = u.user_id
WHERE u.referrer_user_id = '7E0A1E'
  AND u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
ORDER BY u.operation_start_date;

SELECT '=== 3. 運用開始済みユーザーのnft_daily_profit（今日） ===' as section;

SELECT
    ndp.user_id,
    ndp.date,
    COUNT(*) as nft_count,
    SUM(ndp.daily_profit) as total_daily_profit
FROM nft_daily_profit ndp
INNER JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= CURRENT_DATE
  AND ndp.date = CURRENT_DATE
GROUP BY ndp.user_id, ndp.date
ORDER BY ndp.user_id;

SELECT '=== 4. 運用開始済みユーザーのnft_daily_profit（昨日） ===' as section;

SELECT
    ndp.user_id,
    ndp.date,
    COUNT(*) as nft_count,
    SUM(ndp.daily_profit) as total_daily_profit
FROM nft_daily_profit ndp
INNER JOIN users u ON ndp.user_id = u.user_id
WHERE u.operation_start_date IS NOT NULL
  AND u.operation_start_date <= CURRENT_DATE
  AND ndp.date = CURRENT_DATE - INTERVAL '1 day'
GROUP BY ndp.user_id, ndp.date
ORDER BY ndp.user_id;

SELECT '=== 5. 昨日の日付で7E0A1Eの紹介報酬を計算 ===' as section;

SELECT
    referral_user_id,
    referral_level,
    referral_profit,
    referral_amount,
    calculation_date
FROM calculate_daily_referral_rewards('7E0A1E', CURRENT_DATE - INTERVAL '1 day')
ORDER BY referral_level, referral_user_id;

SELECT
    '昨日の合計紹介報酬' as label,
    COALESCE(SUM(referral_amount), 0) as total_referral_reward
FROM calculate_daily_referral_rewards('7E0A1E', CURRENT_DATE - INTERVAL '1 day');

SELECT '=== 6. 7E0A1Eの紹介ツリー全体（運用開始済みのみ） ===' as section;

-- Level 1
WITH level1 AS (
    SELECT u.user_id, u.email, u.operation_start_date, 1 as level
    FROM users u
    WHERE u.referrer_user_id = '7E0A1E'
      AND u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= CURRENT_DATE
),
-- Level 2
level2 AS (
    SELECT u.user_id, u.email, u.operation_start_date, 2 as level
    FROM users u
    INNER JOIN level1 l1 ON u.referrer_user_id = l1.user_id
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= CURRENT_DATE
),
-- Level 3
level3 AS (
    SELECT u.user_id, u.email, u.operation_start_date, 3 as level
    FROM users u
    INNER JOIN level2 l2 ON u.referrer_user_id = l2.user_id
    WHERE u.has_approved_nft = true
      AND u.operation_start_date IS NOT NULL
      AND u.operation_start_date <= CURRENT_DATE
)
SELECT * FROM level1
UNION ALL
SELECT * FROM level2
UNION ALL
SELECT * FROM level3
ORDER BY level, user_id;

SELECT '=== 完了 ===' as section;
