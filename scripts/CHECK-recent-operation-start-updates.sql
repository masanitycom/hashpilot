-- ========================================
-- 本番環境で最近operation_start_dateが更新されたユーザーを確認
-- ========================================

-- ========================================
-- 1. 今日更新されたユーザー
-- ========================================
SELECT
    '今日operation_start_dateが更新されたユーザー' as label,
    u.user_id,
    u.full_name,
    u.operation_start_date,
    u.has_approved_nft,
    u.updated_at,
    COUNT(p.id) as purchase_count,
    SUM(p.amount_usd) as total_paid,
    SUM(p.amount_usd * (1000.0 / 1100.0)) as investment_value
FROM users u
JOIN purchases p ON u.user_id = p.user_id
WHERE p.admin_approved = true
    AND u.operation_start_date IS NOT NULL
    AND DATE(u.updated_at) = CURRENT_DATE
GROUP BY u.user_id, u.full_name, u.operation_start_date, u.has_approved_nft, u.updated_at
ORDER BY u.updated_at DESC;

-- ========================================
-- 2. 過去3日間で更新されたユーザー
-- ========================================
SELECT
    '過去3日間でoperation_start_dateが更新されたユーザー' as label,
    DATE(u.updated_at) as update_date,
    COUNT(DISTINCT u.user_id) as user_count,
    SUM(p.amount_usd * (1000.0 / 1100.0)) as total_investment_value
FROM users u
JOIN purchases p ON u.user_id = p.user_id
WHERE p.admin_approved = true
    AND u.operation_start_date IS NOT NULL
    AND u.updated_at >= CURRENT_DATE - INTERVAL '3 days'
GROUP BY DATE(u.updated_at)
ORDER BY update_date DESC;

-- ========================================
-- 3. has_approved_nftがfalseだが、NFTとpurchasesが存在するユーザー
-- ========================================
SELECT
    'has_approved_nft=falseだがNFT保有' as issue,
    u.user_id,
    u.full_name,
    u.has_approved_nft,
    u.operation_start_date,
    COUNT(DISTINCT nm.id) as nft_count,
    COUNT(DISTINCT p.id) as purchase_count,
    SUM(p.amount_usd * (1000.0 / 1100.0)) as investment_value
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
WHERE u.has_approved_nft = false
GROUP BY u.user_id, u.full_name, u.has_approved_nft, u.operation_start_date
ORDER BY investment_value DESC;

-- ========================================
-- 4. operation_start_date=NULLだが、NFTとpurchasesが存在するユーザー
-- ========================================
SELECT
    'operation_start_date=NULLだがNFT保有' as issue,
    u.user_id,
    u.full_name,
    u.has_approved_nft,
    u.operation_start_date,
    COUNT(DISTINCT nm.id) as nft_count,
    COUNT(DISTINCT p.id) as purchase_count,
    SUM(p.amount_usd * (1000.0 / 1100.0)) as investment_value
FROM users u
JOIN nft_master nm ON u.user_id = nm.user_id AND nm.buyback_date IS NULL
JOIN purchases p ON u.user_id = p.user_id AND p.admin_approved = true
WHERE u.operation_start_date IS NULL
GROUP BY u.user_id, u.full_name, u.has_approved_nft, u.operation_start_date
ORDER BY investment_value DESC;
