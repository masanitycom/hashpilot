-- 緊急修正: 未承認購入を一括処理

-- 1. 現在の未承認購入を確認
SELECT 
    '=== 緊急処理対象 ===' as status,
    p.user_id,
    u.email,
    p.amount_usd,
    p.created_at,
    '未承認購入' as issue
FROM purchases p
JOIN users u ON p.user_id = u.user_id
WHERE p.admin_approved = false
ORDER BY p.created_at;

-- 2. オプション1: 未承認購入を削除（安全）
-- DELETE FROM purchases WHERE admin_approved = false;

-- 3. オプション2: 未承認購入を承認（リスキー）
-- UPDATE purchases 
-- SET admin_approved = true, 
--     admin_approved_at = NOW()
-- WHERE admin_approved = false;

-- 4. まず影響範囲を確認
SELECT 
    COUNT(*) as total_pending,
    SUM(amount_usd::DECIMAL) as total_amount
FROM purchases 
WHERE admin_approved = false;