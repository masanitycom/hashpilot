-- 2A973Bユーザーの購入を手動で承認

-- 2A973Bユーザーの購入状況確認
SELECT 
    'User 2A973B purchase details' as info,
    id,
    user_id,
    amount_usd,
    payment_status,
    admin_approved,
    admin_approved_at,
    admin_approved_by,
    created_at
FROM purchases 
WHERE user_id = '2A973B'
ORDER BY created_at DESC;

-- 手動承認実行
UPDATE purchases 
SET 
    admin_approved = true,
    admin_approved_at = NOW(),
    admin_approved_by = 'basarasystems@gmail.com',
    admin_notes = '手動承認 - 管理画面修復後'
WHERE user_id = '2A973B' 
AND admin_approved = false;

-- usersテーブルも更新
UPDATE users 
SET 
    total_purchases = COALESCE(total_purchases, 0) + 1000,
    has_approved_nft = true
WHERE user_id = '2A973B';

-- 結果確認
SELECT 
    'After manual approval' as info,
    p.id,
    p.user_id,
    p.amount_usd,
    p.admin_approved,
    p.admin_approved_at,
    u.total_purchases,
    u.has_approved_nft
FROM purchases p
JOIN users u ON p.user_id = u.user_id
WHERE p.user_id = '2A973B'
ORDER BY p.created_at DESC;