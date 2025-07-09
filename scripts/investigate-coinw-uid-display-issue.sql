-- CoinW UID表示問題の調査スクリプト（読み取り専用）

-- 1. 最近の登録者のauth.usersテーブルの状況を確認
SELECT 
    'recent_auth_users' as check_type,
    id,
    email,
    raw_user_meta_data->>'coinw_uid' as coinw_uid,
    raw_user_meta_data->>'referrer_user_id' as referrer,
    created_at,
    email_confirmed_at
FROM auth.users 
WHERE created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;

-- 2. usersテーブルとauth.usersテーブルの同期状況を確認
SELECT 
    'sync_status' as check_type,
    u.user_id,
    u.email,
    u.coinw_uid as users_coinw_uid,
    au.raw_user_meta_data->>'coinw_uid' as auth_coinw_uid,
    CASE 
        WHEN u.coinw_uid IS NOT NULL AND au.raw_user_meta_data->>'coinw_uid' IS NOT NULL THEN '✅ 両方設定済み'
        WHEN u.coinw_uid IS NULL AND au.raw_user_meta_data->>'coinw_uid' IS NULL THEN '❌ 両方未設定'
        WHEN u.coinw_uid IS NOT NULL AND au.raw_user_meta_data->>'coinw_uid' IS NULL THEN '⚠️ usersのみ設定'
        WHEN u.coinw_uid IS NULL AND au.raw_user_meta_data->>'coinw_uid' IS NOT NULL THEN '⚠️ authのみ設定'
        ELSE '❓ 不明な状態'
    END as sync_status
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.created_at > NOW() - INTERVAL '24 hours'
ORDER BY u.created_at DESC;

-- 3. 管理画面で使用されるビューの状況確認
SELECT 
    'admin_view_check' as check_type,
    user_id,
    email,
    coinw_uid,
    created_at
FROM admin_purchases_view
WHERE created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;

-- 4. 全体的な統計
SELECT 
    'final_check' as check_type,
    COUNT(*) as total_users,
    COUNT(CASE WHEN coinw_uid IS NOT NULL THEN 1 END) as users_with_coinw_uid,
    ROUND(COUNT(CASE WHEN coinw_uid IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 2) as percentage_with_coinw_uid
FROM users;
