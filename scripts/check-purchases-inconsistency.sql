-- 削除されたAA8D9Bの購入データ整合性確認

-- 1. AA8D9Bの購入レコードが本当に削除されているか確認
SELECT 
    'AA8D9Bの購入レコード確認:' as info,
    COUNT(*) as purchase_records,
    COALESCE(SUM(amount_usd), 0) as total_amount
FROM purchases 
WHERE user_id = 'AA8D9B';

-- 2. 他のユーザーでtotal_purchasesと実際の購入額に不整合がないかチェック
SELECT 
    '整合性チェック:' as info,
    u.user_id,
    u.email,
    u.total_purchases as stored_total,
    COALESCE(SUM(p.amount_usd), 0) as actual_purchase_total,
    (u.total_purchases - COALESCE(SUM(p.amount_usd), 0)) as difference
FROM users u
LEFT JOIN purchases p ON u.user_id = p.user_id
WHERE u.total_purchases > 0
GROUP BY u.user_id, u.email, u.total_purchases
HAVING ABS(u.total_purchases - COALESCE(SUM(p.amount_usd), 0)) > 0.01
ORDER BY difference DESC
LIMIT 10;

-- 3. システムログでAA8D9Bの削除詳細を確認
SELECT 
    operation,
    message,
    details,
    created_at
FROM system_logs
WHERE user_id = 'AA8D9B'
AND operation = 'user_deleted_safely'
ORDER BY created_at DESC
LIMIT 1;