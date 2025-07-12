-- NFT購入データの詳細調査

-- 1. 問題のあるユーザーB43A3Dの購入履歴を詳しく確認
SELECT 
    '🔍 B43A3D購入履歴詳細:' as info,
    id,
    user_id,
    nft_quantity,
    amount_usd,
    payment_status,
    admin_approved,
    admin_approved_at,
    created_at,
    admin_notes
FROM purchases 
WHERE user_id = 'B43A3D'
ORDER BY created_at;

-- 2. Y9FVT1の購入履歴
SELECT 
    '🔍 Y9FVT1購入履歴詳細:' as info,
    id,
    user_id,
    nft_quantity,
    amount_usd,
    payment_status,
    admin_approved,
    admin_approved_at,
    created_at,
    admin_notes
FROM purchases 
WHERE user_id = 'Y9FVT1'
ORDER BY created_at;

-- 3. 0E47BCの購入履歴
SELECT 
    '🔍 0E47BC購入履歴詳細:' as info,
    id,
    user_id,
    nft_quantity,
    amount_usd,
    payment_status,
    admin_approved,
    admin_approved_at,
    created_at,
    admin_notes
FROM purchases 
WHERE user_id = '0E47BC'
ORDER BY created_at;

-- 4. これらのユーザーのusersテーブル情報
SELECT 
    '👤 ユーザー基本情報:' as info,
    user_id,
    email,
    total_purchases,
    has_approved_nft,
    created_at,
    updated_at
FROM users 
WHERE user_id IN ('B43A3D', 'Y9FVT1', '0E47BC')
ORDER BY user_id;

-- 5. 異常な金額の購入がないかチェック
SELECT 
    '💰 異常な購入額の確認:' as info,
    user_id,
    amount_usd,
    nft_quantity,
    (amount_usd / nft_quantity) as price_per_nft,
    CASE 
        WHEN amount_usd % 1100 != 0 THEN '❌ 1100の倍数ではない'
        WHEN (amount_usd / nft_quantity) != 1100 THEN '❌ NFT単価が1100ではない'
        ELSE '✅ 正常'
    END as status,
    created_at
FROM purchases 
WHERE user_id IN ('B43A3D', 'Y9FVT1', '0E47BC')
ORDER BY user_id, created_at;

-- 6. system_logsで承認処理の履歴を確認
SELECT 
    '📋 承認処理ログ:' as info,
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
FROM system_logs 
WHERE user_id IN ('B43A3D', 'Y9FVT1', '0E47BC')
AND operation LIKE '%purchase%'
ORDER BY user_id, created_at;