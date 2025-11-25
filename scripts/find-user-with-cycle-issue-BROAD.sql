-- ========================================
-- 運用開始前ユーザーのサイクル問題調査（広範囲検索）
-- ========================================

-- 1. total_purchases = 1000 または 1100 のユーザー（運用ステータス問わず）
SELECT
    '1. 投資額$1,000-$1,100のユーザー' as section,
    u.user_id,
    u.email,
    u.total_purchases,
    u.operation_start_date,
    CASE
        WHEN u.operation_start_date IS NULL THEN '❌ 運用開始日未設定'
        WHEN u.operation_start_date > CURRENT_DATE THEN '⏳ 運用開始前'
        ELSE '✅ 運用中'
    END as 運用ステータス,
    CURRENT_DATE as 今日,
    u.has_approved_nft,
    u.created_at
FROM users u
WHERE u.total_purchases BETWEEN 1000 AND 1100
ORDER BY u.created_at DESC
LIMIT 20;

-- 2. cum_usdt が $30-$50 の範囲のユーザー（$38.87周辺）
SELECT
    '2. cum_usdt が$30-$50のユーザー' as section,
    ac.user_id,
    ac.cum_usdt,
    ac.available_usdt,
    ac.phase,
    ac.total_nft_count,
    u.total_purchases,
    u.operation_start_date,
    CASE
        WHEN u.operation_start_date IS NULL THEN '❌ 未設定'
        WHEN u.operation_start_date > CURRENT_DATE THEN '⏳ 運用開始前'
        ELSE '✅ 運用中'
    END as 運用ステータス
FROM affiliate_cycle ac
JOIN users u ON u.user_id = ac.user_id
WHERE ac.cum_usdt BETWEEN 30 AND 50
ORDER BY ac.cum_usdt DESC;

-- 3. Level1-3投資額が$50,000-$60,000のユーザー（$54,000周辺）
WITH level_stats AS (
    SELECT
        u1.user_id as root_user,
        COUNT(DISTINCT u2.user_id) as level1_count,
        SUM(CASE WHEN u2.total_purchases > 0 THEN FLOOR(u2.total_purchases / 1100) * 1000 ELSE 0 END) as level1_investment,
        COUNT(DISTINCT u3.user_id) as level2_count,
        SUM(CASE WHEN u3.total_purchases > 0 THEN FLOOR(u3.total_purchases / 1100) * 1000 ELSE 0 END) as level2_investment,
        COUNT(DISTINCT u4.user_id) as level3_count,
        SUM(CASE WHEN u4.total_purchases > 0 THEN FLOOR(u4.total_purchases / 1100) * 1000 ELSE 0 END) as level3_investment
    FROM users u1
    LEFT JOIN users u2 ON u2.referrer_user_id = u1.user_id
    LEFT JOIN users u3 ON u3.referrer_user_id = u2.user_id
    LEFT JOIN users u4 ON u4.referrer_user_id = u3.user_id
    WHERE u1.total_purchases BETWEEN 1000 AND 1100
    GROUP BY u1.user_id
)
SELECT
    '3. Level1-3投資額$50k-$60kのユーザー' as section,
    ls.root_user as user_id,
    u.email,
    u.total_purchases,
    u.operation_start_date,
    CASE
        WHEN u.operation_start_date IS NULL THEN '❌ 未設定'
        WHEN u.operation_start_date > CURRENT_DATE THEN '⏳ 運用開始前'
        ELSE '✅ 運用中'
    END as 運用ステータス,
    ls.level1_investment + ls.level2_investment + ls.level3_investment as level1_3_total,
    (SELECT cum_usdt FROM affiliate_cycle WHERE user_id = ls.root_user) as cum_usdt
FROM level_stats ls
JOIN users u ON u.user_id = ls.root_user
WHERE (ls.level1_investment + ls.level2_investment + ls.level3_investment) BETWEEN 50000 AND 60000;

-- 4. 運用開始前だけど cum_usdt > 0 のユーザー（全員）
SELECT
    '4. 運用開始前で cum_usdt > 0 のユーザー' as section,
    u.user_id,
    u.email,
    u.total_purchases,
    u.operation_start_date,
    ac.cum_usdt,
    ac.available_usdt,
    ac.phase,
    CURRENT_DATE as 今日,
    CASE
        WHEN u.operation_start_date IS NULL THEN '❌ 未設定'
        WHEN u.operation_start_date > CURRENT_DATE THEN '⏳ 運用開始前'
        ELSE '✅ 運用中'
    END as 運用ステータス
FROM users u
JOIN affiliate_cycle ac ON ac.user_id = u.user_id
WHERE (u.operation_start_date IS NULL OR u.operation_start_date > CURRENT_DATE)
    AND ac.cum_usdt > 0
ORDER BY ac.cum_usdt DESC
LIMIT 30;

-- 5. 総NFT数が0だけど cum_usdt > 0 のユーザー
SELECT
    '5. NFT数0だけど cum_usdt > 0' as section,
    u.user_id,
    u.email,
    u.total_purchases,
    u.operation_start_date,
    ac.total_nft_count,
    ac.cum_usdt,
    ac.available_usdt,
    CASE
        WHEN u.operation_start_date IS NULL THEN '❌ 未設定'
        WHEN u.operation_start_date > CURRENT_DATE THEN '⏳ 運用開始前'
        ELSE '✅ 運用中'
    END as 運用ステータス
FROM users u
JOIN affiliate_cycle ac ON ac.user_id = u.user_id
WHERE ac.total_nft_count = 0
    AND ac.cum_usdt > 0
ORDER BY ac.cum_usdt DESC
LIMIT 30;

-- 6. 最近作成されたユーザー（2025年6月以降、投資額$1,000-$1,100）
SELECT
    '6. 最近作成されたユーザー（2025/6以降）' as section,
    u.user_id,
    u.email,
    u.total_purchases,
    u.operation_start_date,
    CASE
        WHEN u.operation_start_date IS NULL THEN '❌ 未設定'
        WHEN u.operation_start_date > CURRENT_DATE THEN '⏳ 運用開始前'
        ELSE '✅ 運用中'
    END as 運用ステータス,
    (SELECT cum_usdt FROM affiliate_cycle WHERE user_id = u.user_id) as cum_usdt,
    u.created_at
FROM users u
WHERE u.total_purchases BETWEEN 1000 AND 1100
    AND u.created_at >= '2025-06-01'
ORDER BY u.created_at DESC
LIMIT 20;
