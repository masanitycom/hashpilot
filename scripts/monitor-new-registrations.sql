-- 新規登録をリアルタイムで監視

-- 1. 最新の登録ユーザーを詳細表示
SELECT 
    'latest_registrations' as monitor_type,
    u.user_id,
    u.email,
    u.coinw_uid,
    u.referrer_user_id,
    au.raw_user_meta_data,
    u.created_at,
    CASE 
        WHEN u.coinw_uid IS NOT NULL AND u.referrer_user_id IS NOT NULL THEN '✅ 完全'
        WHEN u.coinw_uid IS NOT NULL THEN '⚠️ CoinW UIDのみ'
        WHEN u.referrer_user_id IS NOT NULL THEN '⚠️ 紹介者のみ'
        ELSE '❌ データなし'
    END as data_status
FROM users u
LEFT JOIN auth.users au ON u.id = au.id
WHERE u.created_at >= NOW() - INTERVAL '1 hour'
ORDER BY u.created_at DESC;

-- 2. 紹介関係の統計
SELECT 
    'referral_stats' as monitor_type,
    COUNT(*) as total_users,
    COUNT(referrer_user_id) as users_with_referrer,
    COUNT(coinw_uid) as users_with_coinw_uid,
    ROUND(COUNT(referrer_user_id) * 100.0 / COUNT(*), 2) as referrer_percentage,
    ROUND(COUNT(coinw_uid) * 100.0 / COUNT(*), 2) as coinw_percentage
FROM users;

-- 3. 最近1時間の登録成功率
SELECT 
    'recent_success_rate' as monitor_type,
    COUNT(*) as total_recent_registrations,
    COUNT(CASE WHEN coinw_uid IS NOT NULL AND referrer_user_id IS NOT NULL THEN 1 END) as complete_registrations,
    ROUND(
        COUNT(CASE WHEN coinw_uid IS NOT NULL AND referrer_user_id IS NOT NULL THEN 1 END) * 100.0 / 
        NULLIF(COUNT(*), 0), 2
    ) as success_rate_percentage
FROM users 
WHERE created_at >= NOW() - INTERVAL '1 hour';
