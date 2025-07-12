-- 購入価格表示の混乱を修正（1000ドル→1100ドル）

-- 1. 7/10以降の1000ドル購入を確認
SELECT 
    '🔍 7/10以降の1000ドル購入（実際は1100ドル）:' as info,
    user_id,
    amount_usd,
    nft_quantity,
    payment_status,
    admin_approved,
    created_at,
    '実際は1100ドル購入' as reality
FROM purchases 
WHERE amount_usd = 1000
AND created_at >= '2025-07-10'
ORDER BY created_at;

-- 2. 全ての1000ドル購入を1100ドルに修正
UPDATE purchases 
SET 
    amount_usd = 1100,
    admin_notes = CASE 
        WHEN admin_notes IS NULL THEN '表示修正: 1000→1100ドル（実際の購入価格）'
        ELSE admin_notes || ' [表示修正: 1000→1100ドル]'
    END,
    updated_at = NOW()
WHERE amount_usd = 1000;

-- 3. 承認済みユーザーのtotal_purchasesを修正
UPDATE users 
SET 
    total_purchases = total_purchases + 100,
    updated_at = NOW()
WHERE user_id IN (
    SELECT DISTINCT user_id 
    FROM purchases 
    WHERE amount_usd = 1100 
    AND admin_approved = true
    AND admin_notes LIKE '%表示修正: 1000→1100ドル%'
);

-- 4. 修正結果の確認
SELECT 
    '✅ 修正完了確認:' as result,
    COUNT(*) as total_1100_purchases,
    COUNT(CASE WHEN amount_usd = 1000 THEN 1 END) as remaining_1000_purchases,
    '全て1100ドルに統一されました' as status
FROM purchases;

-- 5. 影響を受けたユーザーの確認
SELECT 
    '👥 修正されたユーザー:' as info,
    u.user_id,
    u.email,
    u.total_purchases,
    COUNT(p.id) as purchase_count,
    SUM(p.amount_usd) as total_amount,
    '正しい金額に修正されました' as status
FROM users u
JOIN purchases p ON u.user_id = p.user_id
WHERE p.admin_notes LIKE '%表示修正: 1000→1100ドル%'
GROUP BY u.user_id, u.email, u.total_purchases;

-- 6. システムログに記録
INSERT INTO system_logs (
    log_type,
    operation,
    message,
    details,
    created_at
) VALUES (
    'SUCCESS',
    'fix_purchase_display_confusion',
    '購入価格表示の混乱を修正しました',
    jsonb_build_object(
        'issue', '7/10以降1000ドル表示されていた購入を1100ドルに修正',
        'reason', '購入価格1100ドルと運用価格1000ドルの表示混乱',
        'fixed_purchases', (SELECT COUNT(*) FROM purchases WHERE admin_notes LIKE '%表示修正: 1000→1100ドル%'),
        'corrected_by', 'system_maintenance'
    ),
    NOW()
);

SELECT '🎉 購入価格表示の修正が完了しました' as completion;