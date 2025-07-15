-- ユーザーの運用開始状況を確認

-- Y9FVT1とG7A9637の運用状況チェック
SELECT 
    p.user_id,
    u.email,
    p.amount_usd,
    p.admin_approved,
    p.admin_approved_at,
    CASE 
        WHEN p.admin_approved_at IS NOT NULL 
        THEN p.admin_approved_at + INTERVAL '15 days'
        ELSE NULL 
    END as operation_start_date,
    CASE 
        WHEN p.admin_approved_at IS NOT NULL AND (p.admin_approved_at + INTERVAL '15 days') <= CURRENT_DATE
        THEN '✅ 運用中'
        WHEN p.admin_approved_at IS NOT NULL
        THEN '⏳ 運用開始前'
        ELSE '❌ 未承認'
    END as operation_status,
    CASE 
        WHEN p.admin_approved_at IS NOT NULL
        THEN CURRENT_DATE - (p.admin_approved_at + INTERVAL '15 days')
        ELSE NULL
    END as days_since_operation_start,
    p.created_at as purchase_date
FROM purchases p
LEFT JOIN users u ON p.user_id = u.user_id
WHERE p.user_id IN ('Y9FVT1', '7A9637')
ORDER BY p.created_at;

-- 日利記録の確認
SELECT 
    user_id,
    COUNT(*) as profit_days,
    SUM(daily_profit) as total_profit,
    MIN(date) as first_profit_date,
    MAX(date) as latest_profit_date
FROM user_daily_profit 
WHERE user_id IN ('Y9FVT1', '7A9637')
GROUP BY user_id;

-- 全ユーザーの運用状況サマリー
SELECT 
    operation_status,
    COUNT(*) as user_count,
    SUM(amount_usd) as total_investment
FROM (
    SELECT 
        p.user_id,
        p.amount_usd,
        CASE 
            WHEN p.admin_approved_at IS NOT NULL AND (p.admin_approved_at + INTERVAL '15 days') <= CURRENT_DATE
            THEN '運用中'
            WHEN p.admin_approved_at IS NOT NULL
            THEN '運用開始前'
            ELSE '未承認'
        END as operation_status
    FROM purchases p
    WHERE p.admin_approved = true
) t
GROUP BY operation_status
ORDER BY operation_status;