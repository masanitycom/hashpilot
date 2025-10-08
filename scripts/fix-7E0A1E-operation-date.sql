-- ========================================
-- 7E0A1Eの運用開始日を修正
-- ========================================

SELECT '=== 修正前の状態確認 ===' as section;

SELECT
    u.user_id,
    u.email,
    u.operation_start_date as current_operation_start,
    p.first_approval_date,
    EXTRACT(DAY FROM p.first_approval_date AT TIME ZONE 'Asia/Tokyo') as approved_day,
    calculate_operation_start_date(p.first_approval_date) as correct_operation_start
FROM users u
LEFT JOIN (
    SELECT user_id, MIN(admin_approved_at) as first_approval_date
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.user_id = '7E0A1E';

SELECT '=== 7E0A1Eの運用開始日を修正 ===' as section;

UPDATE users u
SET operation_start_date = calculate_operation_start_date(p.admin_approved_at)
FROM (
    SELECT user_id, MIN(admin_approved_at) as admin_approved_at
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
      AND user_id = '7E0A1E'
    GROUP BY user_id
) p
WHERE u.user_id = p.user_id;

SELECT '=== 修正後の状態確認 ===' as section;

SELECT
    u.user_id,
    u.email,
    u.operation_start_date,
    CASE
        WHEN u.operation_start_date <= CURRENT_DATE THEN '✅ 運用開始済み'
        ELSE '⏳ 運用開始前（あと' || (u.operation_start_date - CURRENT_DATE) || '日）'
    END as status
FROM users u
WHERE u.user_id = '7E0A1E';
