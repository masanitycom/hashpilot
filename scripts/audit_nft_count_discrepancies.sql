-- ========================================
-- NFT数と購入金額の不整合を全ユーザーで監査
-- ========================================

-- 1. 不整合があるユーザーを特定
WITH purchase_summary AS (
    SELECT 
        user_id,
        COUNT(*) as purchase_count,
        SUM(nft_quantity) as total_nft_purchased,
        SUM(amount_usd) as total_amount_paid
    FROM purchases
    WHERE admin_approved = true
    GROUP BY user_id
),
user_data AS (
    SELECT 
        u.user_id,
        u.email,
        u.total_purchases as recorded_amount,
        ac.total_nft_count as recorded_nft_count,
        ac.manual_nft_count,
        ac.auto_nft_count,
        ps.purchase_count,
        ps.total_nft_purchased as actual_nft_count,
        ps.total_amount_paid as actual_amount
    FROM users u
    LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
    LEFT JOIN purchase_summary ps ON u.user_id = ps.user_id
    WHERE u.has_approved_nft = true
)
SELECT 
    user_id,
    email,
    recorded_amount,
    actual_amount,
    recorded_amount - COALESCE(actual_amount, 0) as amount_diff,
    recorded_nft_count,
    actual_nft_count,
    recorded_nft_count - COALESCE(actual_nft_count, 0) as nft_diff,
    CASE 
        WHEN recorded_amount != COALESCE(actual_amount, 0) THEN '金額不一致'
        WHEN recorded_nft_count != COALESCE(actual_nft_count, 0) THEN 'NFT数不一致'
        ELSE '正常'
    END as status
FROM user_data
WHERE recorded_amount != COALESCE(actual_amount, 0) 
   OR recorded_nft_count != COALESCE(actual_nft_count, 0)
ORDER BY amount_diff DESC, nft_diff DESC;

-- 2. 870323と同じパターン（購入履歴の2倍カウント）のユーザーを特定
SELECT 
    '2倍カウントの疑いがあるユーザー' as category,
    u.user_id,
    u.email,
    u.total_purchases,
    COUNT(p.id) as purchase_records,
    SUM(p.amount_usd) as actual_total,
    u.total_purchases / NULLIF(SUM(p.amount_usd), 0) as multiplier
FROM users u
LEFT JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
WHERE u.has_approved_nft = true
GROUP BY u.user_id, u.email, u.total_purchases
HAVING u.total_purchases = SUM(p.amount_usd) * 2
ORDER BY u.user_id;

-- 3. NFT数の詳細分析
SELECT 
    'NFT数詳細分析' as analysis,
    ac.user_id,
    u.email,
    ac.total_nft_count as recorded_total,
    ac.manual_nft_count as recorded_manual,
    ac.auto_nft_count as recorded_auto,
    COALESCE(p.nft_sum, 0) as actual_purchased,
    ac.total_nft_count - COALESCE(p.nft_sum, 0) as discrepancy
FROM affiliate_cycle ac
JOIN users u ON ac.user_id = u.user_id
LEFT JOIN (
    SELECT user_id, SUM(nft_quantity) as nft_sum
    FROM purchases
    WHERE admin_approved = true
    GROUP BY user_id
) p ON ac.user_id = p.user_id
WHERE ac.total_nft_count != COALESCE(p.nft_sum, 0)
ORDER BY discrepancy DESC;

-- 4. 修正が必要なユーザーのリスト
SELECT 
    'Action Required' as action,
    u.user_id,
    u.email,
    u.total_purchases as current_amount,
    COALESCE(p.total_amount, 0) as correct_amount,
    ac.total_nft_count as current_nft,
    COALESCE(p.nft_count, 0) as correct_nft,
    CONCAT('UPDATE users SET total_purchases = ', COALESCE(p.total_amount, 0), ' WHERE user_id = ''', u.user_id, ''';') as fix_sql_users,
    CONCAT('UPDATE affiliate_cycle SET total_nft_count = ', COALESCE(p.nft_count, 0), ', manual_nft_count = ', COALESCE(p.nft_count, 0), ' WHERE user_id = ''', u.user_id, ''';') as fix_sql_cycle
FROM users u
LEFT JOIN affiliate_cycle ac ON u.user_id = ac.user_id
LEFT JOIN (
    SELECT user_id, 
           SUM(amount_usd) as total_amount,
           SUM(nft_quantity) as nft_count
    FROM purchases
    WHERE admin_approved = true
    GROUP BY user_id
) p ON u.user_id = p.user_id
WHERE u.has_approved_nft = true
  AND (u.total_purchases != COALESCE(p.total_amount, 0) 
       OR ac.total_nft_count != COALESCE(p.nft_count, 0))
ORDER BY u.user_id;