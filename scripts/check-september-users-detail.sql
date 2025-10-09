-- ========================================
-- 9月承認ユーザーの詳細確認
-- ========================================

SELECT
    u.user_id,
    u.email,
    (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE as approved_date,
    EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') as day,
    u.operation_start_date,
    CASE
        WHEN u.operation_start_date = '2025-09-15' THEN '✅ 正しい (9/1-9/5承認→9/15)'
        WHEN u.operation_start_date = '2025-10-01' THEN '✅ 正しい (9/6-9/30承認→10/1)'
        ELSE '❌ 間違い'
    END as validation
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
ORDER BY p.admin_approved_at
LIMIT 50;
