-- 承認済み1000ドル購入の緊急修正

-- 1. 現在の状況を詳しく確認
SELECT 
    '🔍 承認済み1000ドル購入の詳細:' as info,
    u.user_id,
    u.email,
    u.total_purchases,
    p.amount_usd,
    p.admin_approved_at,
    p.admin_notes,
    '差額: +100ドル必要' as correction_needed
FROM users u
JOIN purchases p ON u.user_id = p.user_id
WHERE p.amount_usd = 1000 AND p.admin_approved = true;

-- 2. 修正オプション1: 1000ドルを1100ドルに修正
-- 注意: これは既に承認済みなので慎重に実行
/*
UPDATE purchases 
SET 
    amount_usd = 1100,
    admin_notes = admin_notes || ' [修正: 1000→1100ドル ' || NOW() || ']'
WHERE amount_usd = 1000 
AND admin_approved = true;

-- total_purchasesも修正
UPDATE users 
SET total_purchases = total_purchases + 100
WHERE user_id IN ('2A973B', 'DB4690');
*/

-- 3. 修正オプション2: 追加100ドルの補償レコード作成
/*
INSERT INTO purchases (
    user_id, 
    nft_quantity, 
    amount_usd, 
    payment_status, 
    admin_approved, 
    admin_approved_by,
    admin_approved_at,
    admin_notes,
    created_at
) VALUES 
('2A973B', 0, 100, 'payment_confirmed', true, 'system_correction', NOW(), '1000ドル承認の差額補償', NOW()),
('DB4690', 0, 100, 'payment_confirmed', true, 'system_correction', NOW(), '1000ドル承認の差額補償', NOW());

-- total_purchasesを更新
UPDATE users SET total_purchases = total_purchases + 100 WHERE user_id IN ('2A973B', 'DB4690');
*/

-- 4. これらのユーザーのaffiliate_cycleも確認
SELECT 
    '🔄 affiliate_cycle確認:' as info,
    user_id,
    total_nft_count,
    manual_nft_count,
    'NFT数は正しく1個か？' as check_point
FROM affiliate_cycle 
WHERE user_id IN ('2A973B', 'DB4690');

-- 5. 推奨案の提示
SELECT 
    '💡 推奨修正案:' as recommendation,
    '承認済み1000ドル購入を1100ドルに修正' as option1,
    'total_purchasesに100ドル追加' as option2,
    'ユーザーに100ドル分の追加利益を提供' as option3;