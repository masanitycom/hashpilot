-- AA8D9B（masataka.tak+69@gmail.com）を安全に削除

-- 1. 削除前の最終確認
SELECT 
    '🎯 削除対象ユーザー最終確認:' as info,
    user_id,
    email,
    total_purchases,
    has_approved_nft,
    created_at
FROM users
WHERE user_id = 'AA8D9B';

-- 2. 関連データの詳細確認
SELECT 
    '📊 affiliate_cycle データ:' as info,
    user_id,
    phase,
    total_nft_count,
    manual_nft_count,
    auto_nft_count,
    cum_usdt,
    available_usdt
FROM affiliate_cycle
WHERE user_id = 'AA8D9B';

-- 3. 実際に削除実行
SELECT * FROM delete_user_safely('AA8D9B', 'masataka.tak@gmail.com');

-- 4. 削除後の確認
SELECT 
    '✅ 削除完了確認:' as info,
    COUNT(*) as remaining_records,
    CASE 
        WHEN COUNT(*) = 0 THEN '完全に削除されました'
        ELSE '削除に失敗しました'
    END as status
FROM users 
WHERE user_id = 'AA8D9B';

-- 5. affiliate_cycleからも削除されたか確認
SELECT 
    '✅ affiliate_cycle削除確認:' as info,
    COUNT(*) as remaining_affiliate_records,
    CASE 
        WHEN COUNT(*) = 0 THEN 'affiliate_cycleからも削除されました'
        ELSE 'affiliate_cycleに残っています'
    END as status
FROM affiliate_cycle 
WHERE user_id = 'AA8D9B';

-- 6. システムログの確認
SELECT 
    '📝 削除ログ:' as info,
    log_type,
    operation,
    message,
    details,
    created_at
FROM system_logs
WHERE operation = 'user_deleted_safely'
AND user_id = 'AA8D9B'
ORDER BY created_at DESC
LIMIT 1;