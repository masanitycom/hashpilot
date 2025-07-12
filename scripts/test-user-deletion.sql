-- ユーザー削除機能のテストスクリプト

-- 1. 削除可能なテストユーザーを探す
SELECT 
    'テストユーザー候補:' as info,
    u.user_id,
    u.email,
    u.created_at::date as created_date,
    COALESCE(u.total_purchases, 0) as total_purchases,
    CASE 
        WHEN u.email LIKE '%test%' THEN '✓ テストユーザー'
        WHEN u.email LIKE '%demo%' THEN '✓ デモユーザー'
        WHEN COALESCE(u.total_purchases, 0) = 0 THEN '✓ 未購入ユーザー'
        ELSE '× 本番ユーザー'
    END as deletion_safe
FROM users u
WHERE 
    u.email LIKE '%test%' 
    OR u.email LIKE '%demo%'
    OR (u.created_at > NOW() - INTERVAL '30 days' AND COALESCE(u.total_purchases, 0) = 0)
ORDER BY 
    CASE 
        WHEN u.email LIKE '%test%' THEN 1
        WHEN u.email LIKE '%demo%' THEN 2
        ELSE 3
    END,
    u.created_at DESC
LIMIT 10;

-- 2. 特定のユーザーの関連データを確認（削除前の確認）
-- ユーザーIDを指定してください
WITH check_user AS (
    SELECT 'ここにユーザーIDを入力'::TEXT as target_user_id
)
SELECT 
    u.user_id,
    u.email,
    u.created_at,
    jsonb_build_object(
        'total_purchases', COALESCE(u.total_purchases, 0),
        'has_approved_nft', u.has_approved_nft,
        'referred_by', u.referrer_user_id,
        'referred_users', (SELECT COUNT(*) FROM users WHERE referrer_user_id = u.user_id),
        'purchases', (SELECT COUNT(*) FROM purchases WHERE user_id = u.user_id),
        'affiliate_cycle', EXISTS(SELECT 1 FROM affiliate_cycle WHERE user_id = u.user_id),
        'buyback_requests', (SELECT COUNT(*) FROM buyback_requests WHERE user_id = u.user_id),
        'daily_profits', (SELECT COUNT(*) FROM user_daily_profit WHERE user_id = u.user_id)
    ) as user_data
FROM users u, check_user cu
WHERE u.user_id = cu.target_user_id;

-- 3. 削除関数のテスト実行
-- 注意: 実際に削除されます！慎重に実行してください
-- SELECT * FROM delete_user_safely('削除するユーザーID', '管理者メールアドレス');

-- 4. 削除後の確認
-- 削除したユーザーIDで以下を実行して、完全に削除されたか確認
-- SELECT COUNT(*) as remaining_records FROM users WHERE user_id = '削除したユーザーID';

-- 5. 削除ログの確認
SELECT 
    log_type,
    operation,
    user_id,
    message,
    details,
    created_at
FROM system_logs
WHERE operation = 'user_deleted_safely'
ORDER BY created_at DESC
LIMIT 5;