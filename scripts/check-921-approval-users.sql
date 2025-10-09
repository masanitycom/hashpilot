-- ========================================
-- 9/21承認なのに11/1運用開始になっているユーザーを調査
-- ========================================

SELECT '=== 1. 9月承認ユーザーの運用開始日 ===' as section;

SELECT
    u.user_id,
    u.email,
    p.admin_approved_at,
    (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE as approved_date_jst,
    EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') as approved_day,
    u.operation_start_date,
    CASE
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 5 THEN '当月15日ルール'
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 20 THEN '翌月1日ルール'
        ELSE '20日以降→翌月1日ルール'
    END as expected_rule,
    CASE
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 5 THEN
            DATE_TRUNC('month', (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE)::DATE + INTERVAL '14 days'
        ELSE
            (DATE_TRUNC('month', (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE) + INTERVAL '1 month')::DATE
    END as expected_operation_start_date
FROM users u
INNER JOIN (
    SELECT user_id, MIN(admin_approved_at) as admin_approved_at
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.has_approved_nft = true
  AND EXTRACT(MONTH FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') = 9
  AND EXTRACT(YEAR FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') = 2025
ORDER BY p.admin_approved_at;

SELECT '=== 2. 運用開始日が期待値と異なるユーザー ===' as section;

SELECT
    u.user_id,
    u.email,
    (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE as approved_date,
    EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') as day,
    u.operation_start_date as actual,
    CASE
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 5 THEN
            DATE_TRUNC('month', (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE)::DATE + INTERVAL '14 days'
        ELSE
            (DATE_TRUNC('month', (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE) + INTERVAL '1 month')::DATE
    END as expected,
    '不一致' as status
FROM users u
INNER JOIN (
    SELECT user_id, MIN(admin_approved_at) as admin_approved_at
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.has_approved_nft = true
  AND u.operation_start_date != CASE
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 5 THEN
            DATE_TRUNC('month', (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE)::DATE + INTERVAL '14 days'
        ELSE
            (DATE_TRUNC('month', (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE) + INTERVAL '1 month')::DATE
    END;

SELECT '=== 3. 9/21承認ユーザーの詳細 ===' as section;

SELECT
    u.user_id,
    u.email,
    p.admin_approved_at,
    p.admin_approved_at AT TIME ZONE 'Asia/Tokyo' as approved_at_jst,
    p.admin_approved_at AT TIME ZONE 'UTC' as approved_at_utc,
    u.operation_start_date
FROM users u
INNER JOIN (
    SELECT user_id, MIN(admin_approved_at) as admin_approved_at
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.has_approved_nft = true
  AND (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE = '2025-09-21';

SELECT '=== 完了 ===' as section;
