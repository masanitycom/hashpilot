-- total_purchases不整合の修正

-- 1. 現在の不整合状況を確認
WITH purchase_totals AS (
    SELECT 
        user_id,
        COALESCE(SUM(amount_usd), 0) as actual_total
    FROM purchases
    WHERE admin_approved = true
    GROUP BY user_id
)
SELECT 
    '修正対象ユーザー:' as info,
    u.user_id,
    u.email,
    u.total_purchases as current_stored,
    pt.actual_total as should_be,
    (pt.actual_total - u.total_purchases) as correction_needed
FROM users u
LEFT JOIN purchase_totals pt ON u.user_id = pt.user_id
WHERE ABS(COALESCE(u.total_purchases, 0) - COALESCE(pt.actual_total, 0)) > 0.01
ORDER BY correction_needed DESC;

-- 2. 修正実行（コメントアウト - 必要に応じて実行）
/*
UPDATE users 
SET total_purchases = (
    SELECT COALESCE(SUM(amount_usd), 0)
    FROM purchases 
    WHERE purchases.user_id = users.user_id 
    AND admin_approved = true
)
WHERE user_id IN ('B43A3D', 'Y9FVT1', '0E47BC');
*/

-- 3. 修正後の確認用クエリ
/*
SELECT 
    '修正後確認:' as info,
    u.user_id,
    u.email,
    u.total_purchases as updated_total,
    COALESCE(SUM(p.amount_usd), 0) as actual_purchase_total
FROM users u
LEFT JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
WHERE u.user_id IN ('B43A3D', 'Y9FVT1', '0E47BC')
GROUP BY u.user_id, u.email, u.total_purchases;
*/