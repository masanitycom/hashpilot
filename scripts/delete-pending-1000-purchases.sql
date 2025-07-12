-- 未承認1000ドル購入の削除

-- 1. 削除前の最終確認
SELECT 
    '🗑️ 削除対象の未承認1000ドル購入:' as info,
    user_id,
    id,
    amount_usd,
    nft_quantity,
    payment_status,
    created_at,
    'これらを削除します' as action
FROM purchases 
WHERE amount_usd = 1000 
AND admin_approved = false
ORDER BY created_at;

-- 2. 実際の削除実行
DELETE FROM purchases 
WHERE amount_usd = 1000 
AND admin_approved = false;

-- 3. 削除結果の確認
SELECT 
    '✅ 削除完了確認:' as result,
    COUNT(*) as remaining_1000_purchases,
    CASE 
        WHEN COUNT(*) = 2 THEN '正常：承認済み2件のみ残存'
        ELSE '要確認：予期しない件数'
    END as status
FROM purchases 
WHERE amount_usd = 1000;

-- 4. システムログに記録
INSERT INTO system_logs (
    log_type,
    operation,
    message,
    details,
    created_at
) VALUES (
    'ADMIN',
    'cleanup_invalid_purchases',
    '未承認1000ドル購入を削除しました',
    jsonb_build_object(
        'reason', '1100ドル単位でないため無効',
        'deleted_count', (SELECT COUNT(*) FROM purchases WHERE amount_usd = 1000 AND admin_approved = false),
        'deleted_by', 'system_maintenance'
    ),
    NOW()
);

SELECT '🎯 未承認1000ドル購入の削除が完了しました' as completion;