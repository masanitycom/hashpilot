-- ========================================
-- 9月承認ユーザーの運用開始日を修正
-- ========================================

SELECT '=== 1. calculate_operation_start_date関数をテスト ===' as section;

-- 9月の各日付でテスト
SELECT
    test_date,
    EXTRACT(DAY FROM test_date) as day,
    calculate_operation_start_date(test_date::TIMESTAMPTZ) as calculated_start_date,
    CASE
        WHEN EXTRACT(DAY FROM test_date) <= 5 THEN '9/15'
        WHEN EXTRACT(DAY FROM test_date) <= 20 THEN '10/1'
        ELSE '10/1'
    END as expected
FROM (
    SELECT '2025-09-01'::DATE as test_date
    UNION ALL SELECT '2025-09-05'::DATE
    UNION ALL SELECT '2025-09-06'::DATE
    UNION ALL SELECT '2025-09-15'::DATE
    UNION ALL SELECT '2025-09-20'::DATE
    UNION ALL SELECT '2025-09-21'::DATE
    UNION ALL SELECT '2025-09-30'::DATE
) tests;

SELECT '=== 2. 実際の9月承認ユーザーの状態 ===' as section;

SELECT
    u.user_id,
    u.email,
    (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE as approved_date,
    EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') as day,
    u.operation_start_date as current_operation_start,
    calculate_operation_start_date(p.admin_approved_at) as should_be
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

SELECT '=== 3. 修正が必要なユーザー数 ===' as section;

SELECT
    COUNT(*) as incorrect_count,
    '9月承認ユーザーで運用開始日が間違っている数' as description
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
  AND u.operation_start_date != calculate_operation_start_date(p.admin_approved_at);

SELECT '=== 4. 全ユーザーの運用開始日を再計算して修正 ===' as section;

UPDATE users u
SET operation_start_date = calculate_operation_start_date(p.admin_approved_at)
FROM (
    SELECT user_id, MIN(admin_approved_at) as admin_approved_at
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p
WHERE u.user_id = p.user_id
  AND u.has_approved_nft = true;

SELECT '修正完了' as status, '全ユーザーの運用開始日を再計算しました' as message;

SELECT '=== 5. 修正後の9月承認ユーザー確認 ===' as section;

SELECT
    u.user_id,
    u.email,
    (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE as approved_date,
    EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') as day,
    u.operation_start_date,
    CASE
        WHEN u.operation_start_date <= CURRENT_DATE THEN '運用開始済み'
        ELSE '運用開始前（あと' || (u.operation_start_date - CURRENT_DATE) || '日）'
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
ORDER BY u.operation_start_date, p.admin_approved_at;

SELECT '=== 完了 ===' as section;
