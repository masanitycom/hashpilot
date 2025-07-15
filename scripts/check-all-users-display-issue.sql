-- システム全体のユーザー表示問題を調査

-- 1. 利益記録があるのに表示問題があるかもしれないユーザーを調査
WITH user_profit_summary AS (
    SELECT 
        udp.user_id,
        u.email,
        COUNT(udp.date) as profit_days,
        SUM(udp.daily_profit::DECIMAL) as total_profit,
        MIN(udp.date) as first_profit_date,
        MAX(udp.date) as latest_profit_date
    FROM user_daily_profit udp
    JOIN users u ON udp.user_id = u.user_id
    GROUP BY udp.user_id, u.email
),
user_purchase_status AS (
    SELECT 
        p.user_id,
        COUNT(*) as total_purchases,
        COUNT(CASE WHEN p.admin_approved = true THEN 1 END) as approved_purchases,
        COUNT(CASE WHEN p.admin_approved = false THEN 1 END) as pending_purchases,
        MIN(CASE WHEN p.admin_approved = true THEN p.admin_approved_at END) as first_approval_date
    FROM purchases p
    GROUP BY p.user_id
)
SELECT 
    '=== 潜在的な表示問題ユーザー ===' as analysis,
    ups.user_id,
    ups.email,
    ups.profit_days,
    ups.total_profit,
    upu.total_purchases,
    upu.approved_purchases,
    upu.pending_purchases,
    CASE 
        WHEN upu.pending_purchases > 0 THEN '⚠️ 未承認購入あり'
        WHEN ups.profit_days > 0 AND ups.total_profit > 0 THEN '✅ 正常'
        ELSE '❓ 要確認'
    END as status_flag
FROM user_profit_summary ups
LEFT JOIN user_purchase_status upu ON ups.user_id = upu.user_id
ORDER BY 
    upu.pending_purchases DESC,
    ups.total_profit DESC;

-- 2. 複数購入しているユーザーの詳細
SELECT 
    '=== 複数購入ユーザーの詳細 ===' as analysis,
    p.user_id,
    u.email,
    p.amount_usd,
    p.admin_approved,
    p.admin_approved_at,
    p.created_at as purchase_date,
    ROW_NUMBER() OVER (PARTITION BY p.user_id ORDER BY p.created_at) as purchase_order
FROM purchases p
JOIN users u ON p.user_id = u.user_id
WHERE p.user_id IN (
    SELECT user_id 
    FROM purchases 
    GROUP BY user_id 
    HAVING COUNT(*) > 1
)
ORDER BY p.user_id, p.created_at;

-- 3. 運用中なのに最近利益がないユーザー
SELECT 
    '=== 運用中だが最近利益なしユーザー ===' as analysis,
    p.user_id,
    u.email,
    p.admin_approved_at,
    p.admin_approved_at + INTERVAL '15 days' as operation_start_date,
    CASE 
        WHEN (p.admin_approved_at + INTERVAL '15 days') <= CURRENT_DATE THEN '運用中'
        ELSE '運用開始前'
    END as operation_status,
    COALESCE(recent_profit.latest_profit_date, 'なし') as latest_profit_date,
    COALESCE(recent_profit.days_since_last_profit, 999) as days_since_last_profit
FROM purchases p
JOIN users u ON p.user_id = u.user_id
LEFT JOIN (
    SELECT 
        user_id,
        MAX(date) as latest_profit_date,
        CURRENT_DATE - MAX(date) as days_since_last_profit
    FROM user_daily_profit
    GROUP BY user_id
) recent_profit ON p.user_id = recent_profit.user_id
WHERE p.admin_approved = true
    AND (p.admin_approved_at + INTERVAL '15 days') <= CURRENT_DATE
    AND (recent_profit.days_since_last_profit > 2 OR recent_profit.latest_profit_date IS NULL)
ORDER BY days_since_last_profit DESC;

-- 4. システム統計
SELECT 
    '=== システム統計 ===' as summary,
    (SELECT COUNT(DISTINCT user_id) FROM users) as total_users,
    (SELECT COUNT(DISTINCT user_id) FROM user_daily_profit) as users_with_profit,
    (SELECT COUNT(DISTINCT user_id) FROM purchases WHERE admin_approved = true) as users_with_approved_nft,
    (SELECT COUNT(*) FROM purchases WHERE admin_approved = false) as pending_approvals
;