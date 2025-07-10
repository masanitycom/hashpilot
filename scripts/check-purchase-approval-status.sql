-- 購入承認状況の確認

-- 最近の購入レコードの状況確認
SELECT 
    'Recent purchases status' as info,
    id,
    user_id,
    amount_usd,
    payment_status,
    admin_approved,
    admin_approved_at,
    admin_approved_by,
    admin_notes,
    created_at
FROM purchases 
ORDER BY created_at DESC
LIMIT 10;

-- 承認済み購入の数
SELECT 
    'Approval summary' as info,
    COUNT(*) as total_purchases,
    COUNT(CASE WHEN admin_approved = true THEN 1 END) as approved_purchases,
    COUNT(CASE WHEN admin_approved = false OR admin_approved IS NULL THEN 1 END) as pending_purchases
FROM purchases;

-- 最新の承認アクティビティ
SELECT 
    'Latest approvals' as info,
    id,
    user_id,
    amount_usd,
    admin_approved_at,
    admin_approved_by
FROM purchases 
WHERE admin_approved = true
ORDER BY admin_approved_at DESC
LIMIT 5;

-- ユーザーの has_approved_nft 状況
SELECT 
    'Users NFT status' as info,
    user_id,
    email,
    total_purchases,
    has_approved_nft,
    created_at
FROM users 
WHERE total_purchases > 0
ORDER BY created_at DESC
LIMIT 10;