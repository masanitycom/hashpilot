-- ========================================
-- 現在のシステム状態を検証
-- ========================================

-- 1. calculate_operation_start_date関数の現在の実装を確認
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'calculate_operation_start_date'
LIMIT 1;

-- 2. 最近承認されたユーザーの運用開始日を確認
SELECT
    u.user_id,
    u.email,
    p.admin_approved_at::date as approved_date,
    EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') as approved_day,
    u.operation_start_date,
    CASE
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 5 THEN '①当月15日'
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 20 THEN '②翌月1日'
        ELSE '③翌月15日'
    END as expected_rule,
    CASE
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 5 THEN
            DATE_TRUNC('month', (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE)::DATE + INTERVAL '14 days'
        WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 20 THEN
            (DATE_TRUNC('month', (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE) + INTERVAL '1 month')::DATE
        ELSE
            (DATE_TRUNC('month', (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE) + INTERVAL '1 month')::DATE + INTERVAL '14 days'
    END as expected_date,
    CASE
        WHEN u.operation_start_date = (
            CASE
                WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 5 THEN
                    DATE_TRUNC('month', (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE)::DATE + INTERVAL '14 days'
                WHEN EXTRACT(DAY FROM p.admin_approved_at AT TIME ZONE 'Asia/Tokyo') <= 20 THEN
                    (DATE_TRUNC('month', (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE) + INTERVAL '1 month')::DATE
                ELSE
                    (DATE_TRUNC('month', (p.admin_approved_at AT TIME ZONE 'Asia/Tokyo')::DATE) + INTERVAL '1 month')::DATE + INTERVAL '14 days'
            END
        ) THEN '✅ 正しい'
        ELSE '❌ 不正'
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
  AND p.admin_approved_at >= '2025-09-01'  -- 9月以降のみ
ORDER BY p.admin_approved_at DESC;

-- 3. 日利処理関数が運用開始日をチェックしているか確認
SELECT
    routine_name,
    routine_definition LIKE '%operation_start_date%' as checks_operation_start_date
FROM information_schema.routines
WHERE routine_name = 'process_daily_yield_with_cycles';

-- 4. 今日（10/12）時点で運用開始しているべきユーザー数
SELECT
    COUNT(*) as should_be_operational,
    STRING_AGG(user_id, ', ') as user_ids
FROM users
WHERE operation_start_date IS NOT NULL
  AND operation_start_date <= '2025-10-12';
