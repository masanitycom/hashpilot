-- ========================================
-- 7E0A1Eの承認日と運用開始日を確認
-- ========================================

SELECT '=== 7E0A1Eのユーザー情報 ===' as section;

SELECT
    user_id,
    email,
    has_approved_nft,
    operation_start_date,
    created_at
FROM users
WHERE user_id = '7E0A1E';

SELECT '=== 7E0A1Eの購入履歴 ===' as section;

SELECT
    id,
    user_id,
    nft_quantity,
    amount_usd,
    admin_approved,
    admin_approved_at,
    (admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE as approved_date_jst,
    EXTRACT(DAY FROM admin_approved_at AT TIME ZONE 'Asia/Tokyo') as approved_day,
    admin_approved_by,
    created_at,
    is_auto_purchase
FROM purchases
WHERE user_id = '7E0A1E'
ORDER BY created_at;

SELECT '=== 7E0A1Eの最初の承認日 ===' as section;

SELECT
    user_id,
    MIN(admin_approved_at) as first_approval,
    (MIN(admin_approved_at) AT TIME ZONE 'Asia/Tokyo')::DATE as first_approval_jst,
    EXTRACT(DAY FROM MIN(admin_approved_at) AT TIME ZONE 'Asia/Tokyo') as approved_day,
    calculate_operation_start_date(MIN(admin_approved_at)) as calculated_operation_start
FROM purchases
WHERE user_id = '7E0A1E'
  AND admin_approved = true
  AND admin_approved_at IS NOT NULL
GROUP BY user_id;

SELECT '=== 現在のoperation_start_dateと期待値の比較 ===' as section;

SELECT
    u.user_id,
    u.operation_start_date as current_value,
    calculate_operation_start_date(MIN(p.admin_approved_at)) as expected_value,
    CASE
        WHEN u.operation_start_date = calculate_operation_start_date(MIN(p.admin_approved_at)) THEN '✅ 一致'
        ELSE '❌ 不一致'
    END as status
FROM users u
INNER JOIN purchases p ON u.user_id = p.user_id
WHERE u.user_id = '7E0A1E'
  AND p.admin_approved = true
  AND p.admin_approved_at IS NOT NULL
GROUP BY u.user_id, u.operation_start_date;
