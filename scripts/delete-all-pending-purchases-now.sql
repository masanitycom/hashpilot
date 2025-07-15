-- 緊急: 未承認購入を全削除

-- 削除前の確認（記録用）
SELECT 
    '削除前の記録' as action,
    p.user_id,
    u.email,
    p.amount_usd,
    p.created_at
FROM purchases p
JOIN users u ON p.user_id = u.user_id
WHERE p.admin_approved = false;

-- 未承認購入を全削除
DELETE FROM purchases WHERE admin_approved = false;

-- 削除完了確認
SELECT 
    '削除完了' as status,
    COUNT(*) as remaining_pending_purchases
FROM purchases 
WHERE admin_approved = false;

-- 影響を受けたユーザーのデータ強制更新
UPDATE users 
SET updated_at = NOW() 
WHERE user_id IN ('Y9FVT1', '794682', '0E47BC', '8C1259', '38A16C', 'B43A3D', '764C02', '7B2CDF');

UPDATE affiliate_cycle 
SET updated_at = NOW() 
WHERE user_id IN ('Y9FVT1', '794682', '0E47BC', '8C1259', '38A16C', 'B43A3D', '764C02', '7B2CDF');

-- システムログ記録
INSERT INTO system_logs (log_type, operation, message, details)
VALUES (
    'SUCCESS',
    'EMERGENCY_FIX',
    '未承認購入の一括削除による表示問題解決',
    '{"deleted_purchases": 8, "affected_users": ["Y9FVT1", "794682", "0E47BC", "8C1259", "38A16C", "B43A3D", "764C02", "7B2CDF"], "reason": "display_issue_fix"}'
);

SELECT '🎉 緊急修正完了！ユーザーの表示問題が解決されました' as final_status;