-- ========================================
-- 9月21日～30日承認ユーザーの運用開始日チェック
-- これらのユーザーは「翌月15日ルール」で10/15開始のはず
-- ========================================

SELECT
    u.user_id,
    u.email,
    p.admin_approved_at AT TIME ZONE 'Asia/Tokyo' as approved_jst,
    EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') as approved_day,
    u.operation_start_date,
    CASE
        WHEN u.operation_start_date = '2025-10-15' THEN '✅ 正しい (10/15)'
        WHEN u.operation_start_date = '2025-10-01' THEN '❌ 間違い (10/1になっている)'
        ELSE '⚠️ その他: ' || u.operation_start_date::TEXT
    END as status,
    CASE
        WHEN CURRENT_DATE >= u.operation_start_date THEN '運用開始済み'
        ELSE '運用待機中（あと' || (u.operation_start_date - CURRENT_DATE) || '日）'
    END as current_status
FROM users u
INNER JOIN (
    SELECT user_id, MIN(admin_approved_at) as admin_approved_at
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.has_approved_nft = true
  AND EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') >= 21
  AND p.admin_approved_at AT TIME ZONE 'Asia/Tokyo' >= '2025-09-21'
  AND p.admin_approved_at AT TIME ZONE 'Asia/Tokyo' < '2025-10-01'
ORDER BY p.admin_approved_at;

-- 集計
SELECT
    CASE
        WHEN u.operation_start_date = '2025-10-15' THEN '✅ 正しい (10/15)'
        WHEN u.operation_start_date = '2025-10-01' THEN '❌ 間違い (10/1)'
        ELSE '⚠️ その他'
    END as status,
    COUNT(*) as count
FROM users u
INNER JOIN (
    SELECT user_id, MIN(admin_approved_at) as admin_approved_at
    FROM purchases
    WHERE admin_approved = true
      AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.has_approved_nft = true
  AND EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') >= 21
  AND p.admin_approved_at AT TIME ZONE 'Asia/Tokyo' >= '2025-09-21'
  AND p.admin_approved_at AT TIME ZONE 'Asia/Tokyo' < '2025-10-01'
GROUP BY status
ORDER BY status;
