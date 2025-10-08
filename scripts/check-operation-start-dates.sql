-- ========================================
-- 運用開始日の設定状況を確認
-- ========================================

SELECT '=== 1. 7E0A1Eの直接紹介者の運用開始日設定状況 ===' as section;

SELECT
    u.user_id,
    u.email,
    u.has_approved_nft,
    u.operation_start_date,
    CASE
        WHEN u.operation_start_date IS NULL THEN '❌ 未設定'
        WHEN u.operation_start_date <= CURRENT_DATE THEN '✅ 運用開始済み'
        ELSE '⏳ 運用開始前'
    END as status,
    ac.total_nft_count,
    ac.cum_usdt
FROM users u
LEFT JOIN affiliate_cycle ac ON ac.user_id = u.user_id
WHERE u.referrer_user_id = '7E0A1E'
  AND u.has_approved_nft = true
ORDER BY u.operation_start_date NULLS FIRST;

SELECT '=== 2. 全体の運用開始日設定状況 ===' as section;

SELECT
    COUNT(*) FILTER (WHERE operation_start_date IS NULL) as null_count,
    COUNT(*) FILTER (WHERE operation_start_date IS NOT NULL) as set_count,
    COUNT(*) as total_count
FROM users
WHERE has_approved_nft = true;

SELECT '=== 3. purchasesテーブルから最初の承認日を確認 ===' as section;

SELECT
    u.user_id,
    u.email,
    u.operation_start_date as current_operation_start_date,
    p.first_approved_at,
    EXTRACT(DAY FROM (p.first_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE) as approved_day
FROM users u
INNER JOIN (
    SELECT user_id, MIN(admin_approved_at) as first_approved_at
    FROM purchases
    WHERE admin_approved = true AND admin_approved_at IS NOT NULL
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.referrer_user_id = '7E0A1E'
  AND u.has_approved_nft = true
ORDER BY p.first_approved_at;

SELECT '=== 完了 ===' as section;
