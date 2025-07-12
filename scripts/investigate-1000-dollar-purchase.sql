-- 1000ドル購入の詳細調査

-- 1. B43A3Dの1000ドル購入の詳細
SELECT 
    '🚨 異常な1000ドル購入:' as info,
    id,
    user_id,
    nft_quantity,
    amount_usd,
    payment_status,
    admin_approved,
    user_notes,
    admin_notes,
    payment_proof_url,
    created_at,
    updated_at
FROM purchases 
WHERE user_id = 'B43A3D' 
AND amount_usd = 1000;

-- 2. 全システムで1000ドル購入があるかチェック
SELECT 
    '💰 全ての1000ドル購入:' as info,
    user_id,
    nft_quantity,
    amount_usd,
    payment_status,
    admin_approved,
    created_at
FROM purchases 
WHERE amount_usd = 1000
ORDER BY created_at;

-- 3. B43A3Dの正しいtotal_purchasesを計算
SELECT 
    '✅ B43A3D正しい計算:' as info,
    user_id,
    COUNT(*) as total_purchases_count,
    COUNT(CASE WHEN admin_approved = true THEN 1 END) as approved_count,
    COUNT(CASE WHEN admin_approved = false THEN 1 END) as pending_count,
    SUM(CASE WHEN admin_approved = true THEN amount_usd ELSE 0 END) as should_be_total_purchases,
    SUM(amount_usd) as all_purchases_total
FROM purchases 
WHERE user_id = 'B43A3D'
GROUP BY user_id;

-- 4. 1000ドル購入を削除するか修正するかの提案
SELECT 
    '💡 提案:' as info,
    'B43A3Dの1000ドル購入は異常です' as issue,
    '以下の選択肢があります:' as options,
    '1. 1000ドル購入を削除' as option1,
    '2. 1000ドルを1100ドルに修正' as option2,
    '3. そのまま承認（特別な理由がある場合）' as option3;