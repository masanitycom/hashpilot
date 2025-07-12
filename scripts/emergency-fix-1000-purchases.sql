-- 1000ドル購入の緊急対応

-- 1. 承認済みの1000ドル購入の確認（重要！）
SELECT 
    '🚨 承認済み1000ドル購入（緊急確認必要）:' as alert,
    user_id,
    amount_usd,
    nft_quantity,
    admin_approved_by,
    admin_approved_at,
    admin_notes
FROM purchases 
WHERE amount_usd = 1000 
AND admin_approved = true;

-- 2. これらのユーザーのtotal_purchasesが間違っている可能性
SELECT 
    '💰 1000ドルで承認されたユーザーの投資額:' as info,
    u.user_id,
    u.email,
    u.total_purchases,
    'この金額は1000ドル分多い可能性' as note
FROM users u
WHERE u.user_id IN (
    SELECT DISTINCT user_id 
    FROM purchases 
    WHERE amount_usd = 1000 AND admin_approved = true
);

-- 3. 未承認の1000ドル購入（削除候補）
SELECT 
    '🗑️ 削除対象の未承認1000ドル購入:' as info,
    user_id,
    id,
    created_at,
    'DELETE FROM purchases WHERE id = ''' || id || ''';' as delete_command
FROM purchases 
WHERE amount_usd = 1000 
AND admin_approved = false
ORDER BY created_at;

-- 4. 修正オプション1: 未承認1000ドル購入を1100ドルに修正
/*
UPDATE purchases 
SET amount_usd = 1100 
WHERE amount_usd = 1000 
AND admin_approved = false;
*/

-- 5. 修正オプション2: 未承認1000ドル購入を完全削除
/*
DELETE FROM purchases 
WHERE amount_usd = 1000 
AND admin_approved = false;
*/

-- 6. NFT購入フォームの確認が必要
SELECT 
    '⚠️ 緊急対応必要事項:' as priority,
    '1. NFT購入フォームで1000ドルが入力される原因を調査' as task1,
    '2. 承認済み1000ドル購入の取り扱いを決定' as task2,
    '3. total_purchasesの修正が必要かチェック' as task3,
    '4. 未承認1000ドル購入の削除または修正' as task4;