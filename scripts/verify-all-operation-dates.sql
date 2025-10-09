-- ========================================
-- 全ユーザーの運用開始日を確認
-- ========================================

SELECT '=== 9月承認ユーザーの運用開始日 ===' as section;

SELECT
    u.user_id,
    u.email,
    (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE as approved_date,
    EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') as day,
    u.operation_start_date,
    CASE
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 5 THEN '当月15日'
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 20 THEN '翌月1日'
        ELSE '翌月1日'
    END as expected_rule,
    CASE
        WHEN u.operation_start_date <= CURRENT_DATE THEN '✅ 運用開始済み'
        ELSE '⏳ 運用開始前'
    END as status
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

SELECT '=== 10月承認ユーザーの運用開始日 ===' as section;

SELECT
    u.user_id,
    u.email,
    (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE as approved_date,
    EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') as day,
    u.operation_start_date,
    CASE
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 5 THEN '当月15日'
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 20 THEN '翌月1日'
        ELSE '翌月1日'
    END as expected_rule,
    CASE
        WHEN u.operation_start_date <= CURRENT_DATE THEN '✅ 運用開始済み'
        ELSE '⏳ 運用開始前'
    END as status
FROM users u
INNER JOIN (
    SELECT user_id, MIN(admin_approved_at) as admin_approved_at
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.has_approved_nft = true
  AND EXTRACT(MONTH FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') = 10
  AND EXTRACT(YEAR FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') = 2025
ORDER BY p.admin_approved_at;

SELECT '=== 運用開始日ごとのユーザー数 ===' as section;

SELECT
    u.operation_start_date,
    COUNT(*) as user_count,
    CASE
        WHEN u.operation_start_date <= CURRENT_DATE THEN '✅ 運用開始済み'
        ELSE '⏳ 運用開始前'
    END as status
FROM users u
WHERE u.has_approved_nft = true
  AND u.operation_start_date IS NOT NULL
GROUP BY u.operation_start_date
ORDER BY u.operation_start_date;
