-- CoinW UIDが設定されていないユーザーを確認

-- 最近登録したユーザーでCoinW UIDがない、または空のユーザー
SELECT 
    user_id,
    email,
    full_name,
    coinw_uid,
    referrer_user_id,
    created_at,
    CASE 
        WHEN coinw_uid IS NULL THEN 'NULL値'
        WHEN coinw_uid = '' THEN '空文字'
        ELSE coinw_uid
    END as uid_status
FROM users
WHERE coinw_uid IS NULL OR coinw_uid = ''
ORDER BY created_at DESC
LIMIT 20;

-- 直近1週間で登録されたユーザー
SELECT 
    '=== 直近1週間の新規登録ユーザー ===' as info,
    user_id,
    email,
    full_name,
    coinw_uid,
    referrer_user_id,
    created_at
FROM users
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY created_at DESC;

-- CoinW UIDの設定状況統計
SELECT 
    '=== CoinW UID設定状況統計 ===' as info,
    COUNT(*) as total_users,
    COUNT(CASE WHEN coinw_uid IS NOT NULL AND coinw_uid != '' THEN 1 END) as with_uid,
    COUNT(CASE WHEN coinw_uid IS NULL OR coinw_uid = '' THEN 1 END) as without_uid,
    ROUND(
        COUNT(CASE WHEN coinw_uid IS NOT NULL AND coinw_uid != '' THEN 1 END)::NUMERIC / 
        COUNT(*)::NUMERIC * 100, 
        2
    ) as uid_percentage
FROM users;