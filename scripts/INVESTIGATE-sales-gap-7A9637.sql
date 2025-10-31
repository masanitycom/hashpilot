-- ========================================
-- 売上差額の調査: 7A9637のネットワーク vs 総売上
-- ========================================
-- 紹介ネットワーク: $660,000
-- 総売上: $728,200
-- 差額: $68,200

-- 1. 7A9637のツリー全体を取得
SELECT '=== 1. 7A9637の紹介ツリー ===' as section;

WITH RECURSIVE referral_tree AS (
    -- 7A9637 本人
    SELECT
        user_id,
        email,
        full_name,
        referrer_user_id,
        total_purchases,
        1 as level
    FROM users
    WHERE user_id = '7A9637'

    UNION ALL

    -- 子孫ユーザー（最大500レベル）
    SELECT
        u.user_id,
        u.email,
        u.full_name,
        u.referrer_user_id,
        u.total_purchases,
        rt.level + 1
    FROM users u
    INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
    WHERE rt.level < 500
)
SELECT
    COUNT(*) as total_users_in_tree,
    COUNT(*) FILTER (WHERE total_purchases > 0) as users_with_purchases,
    SUM(total_purchases) as total_tree_sales,
    MAX(level) as max_depth
FROM referral_tree;

-- 2. 7A9637のツリーに含まれるユーザーの詳細
SELECT '=== 2. 7A9637ツリーのユーザーID一覧 ===' as section;

WITH RECURSIVE referral_tree AS (
    SELECT
        user_id,
        referrer_user_id,
        total_purchases,
        1 as level
    FROM users
    WHERE user_id = '7A9637'

    UNION ALL

    SELECT
        u.user_id,
        u.referrer_user_id,
        u.total_purchases,
        rt.level + 1
    FROM users u
    INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
    WHERE rt.level < 500
)
SELECT user_id, total_purchases, level
FROM referral_tree
ORDER BY level, user_id;

-- 3. 7A9637のツリーに含まれないユーザーを抽出
SELECT '=== 3. 7A9637ツリーに含まれないユーザー ===' as section;

WITH RECURSIVE referral_tree AS (
    SELECT user_id
    FROM users
    WHERE user_id = '7A9637'

    UNION ALL

    SELECT u.user_id
    FROM users u
    INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
)
SELECT
    u.user_id,
    u.email,
    u.full_name,
    u.referrer_user_id,
    u.total_purchases,
    u.created_at
FROM users u
WHERE u.user_id NOT IN (SELECT user_id FROM referral_tree)
    AND u.total_purchases > 0
ORDER BY u.total_purchases DESC;

-- 4. 差額の集計
SELECT '=== 4. 差額の詳細 ===' as section;

WITH RECURSIVE referral_tree AS (
    SELECT user_id
    FROM users
    WHERE user_id = '7A9637'

    UNION ALL

    SELECT u.user_id
    FROM users u
    INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
),
tree_sales AS (
    SELECT SUM(total_purchases) as tree_total
    FROM users
    WHERE user_id IN (SELECT user_id FROM referral_tree)
),
total_sales AS (
    SELECT SUM(total_purchases) as all_total
    FROM users
),
outside_tree_sales AS (
    SELECT SUM(total_purchases) as outside_total
    FROM users
    WHERE user_id NOT IN (SELECT user_id FROM referral_tree)
)
SELECT
    ts.tree_total as tree_sales,
    os.all_total as total_sales,
    ots.outside_total as outside_tree_sales,
    os.all_total - ts.tree_total as calculated_gap
FROM tree_sales ts, total_sales os, outside_tree_sales ots;

-- 5. 紹介者がNULLのユーザー（独立ユーザー）
SELECT '=== 5. 紹介者がNULLのユーザー ===' as section;

SELECT
    user_id,
    email,
    full_name,
    total_purchases,
    created_at
FROM users
WHERE referrer_user_id IS NULL
    AND total_purchases > 0
    AND user_id != '7A9637'  -- 7A9637自身を除く
ORDER BY total_purchases DESC;

-- 6. 運用専用ユーザーの確認
SELECT '=== 6. 運用専用ユーザー ===' as section;

SELECT
    user_id,
    email,
    full_name,
    total_purchases,
    is_operation_only,
    referrer_user_id
FROM users
WHERE is_operation_only = true
    AND total_purchases > 0
ORDER BY total_purchases DESC;

-- 7. ペガサス交換ユーザーの確認
SELECT '=== 7. ペガサス交換ユーザー ===' as section;

SELECT
    user_id,
    email,
    full_name,
    total_purchases,
    is_pegasus_exchange,
    pegasus_exchange_date,
    referrer_user_id
FROM users
WHERE is_pegasus_exchange = true
    AND total_purchases > 0
ORDER BY total_purchases DESC;

-- 8. 最終サマリー
SELECT '=== 最終サマリー ===' as section;

SELECT
    '総ユーザー数' as metric,
    COUNT(*)::TEXT as value
FROM users
UNION ALL
SELECT
    '投資済みユーザー数',
    COUNT(*)::TEXT
FROM users
WHERE total_purchases > 0
UNION ALL
SELECT
    '総売上（全ユーザー）',
    TO_CHAR(SUM(total_purchases), 'FM$999,999,999') as value
FROM users
UNION ALL
SELECT
    '7A9637ツリーの売上',
    TO_CHAR(
        (WITH RECURSIVE referral_tree AS (
            SELECT user_id FROM users WHERE user_id = '7A9637'
            UNION ALL
            SELECT u.user_id FROM users u
            INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
        )
        SELECT SUM(total_purchases) FROM users WHERE user_id IN (SELECT user_id FROM referral_tree)),
        'FM$999,999,999'
    )
UNION ALL
SELECT
    '差額（ツリー外の売上）',
    TO_CHAR(
        SUM(total_purchases) - (
            WITH RECURSIVE referral_tree AS (
                SELECT user_id FROM users WHERE user_id = '7A9637'
                UNION ALL
                SELECT u.user_id FROM users u
                INNER JOIN referral_tree rt ON u.referrer_user_id = rt.user_id
            )
            SELECT SUM(total_purchases) FROM users WHERE user_id IN (SELECT user_id FROM referral_tree)
        ),
        'FM$999,999,999'
    )
FROM users;

SELECT '✅ 調査完了' as status;
