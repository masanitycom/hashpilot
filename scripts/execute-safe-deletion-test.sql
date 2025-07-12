-- 実際に安全なユーザーで削除をテスト実行

-- 1. 最も安全な削除候補を選択（NFT未購入、関連データなし）
WITH safest_user AS (
    SELECT user_id, email
    FROM users
    WHERE user_id = 'EFD820'  -- apprecieight@gmail.com
    AND total_purchases = 0
    AND has_approved_nft = false
)
SELECT 
    '実行前確認:' as info,
    su.user_id,
    su.email,
    EXISTS(SELECT 1 FROM affiliate_cycle WHERE user_id = su.user_id) as has_affiliate_cycle,
    EXISTS(SELECT 1 FROM purchases WHERE user_id = su.user_id) as has_purchases,
    (SELECT COUNT(*) FROM users WHERE referrer_user_id = su.user_id) as referrals_count
FROM safest_user su;

-- 2. 実際に削除実行（安全なユーザーのみ）
SELECT * FROM delete_user_safely('EFD820', 'masataka.tak@gmail.com');

-- 3. 削除後の確認
SELECT 
    '削除後確認:' as info,
    COUNT(*) as remaining_user_records,
    'ユーザーが完全に削除されているか確認' as note
FROM users 
WHERE user_id = 'EFD820';

-- 4. システムログの確認
SELECT 
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
FROM system_logs
WHERE operation = 'user_deleted_safely'
AND user_id = 'EFD820'
ORDER BY created_at DESC
LIMIT 1;