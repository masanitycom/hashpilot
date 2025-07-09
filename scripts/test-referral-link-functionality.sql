-- 紹介リンク機能のテスト

-- 1. 現在のトリガー状況
SELECT 
    'current_trigger_status' as check_type,
    tgname as trigger_name,
    tgenabled as enabled,
    proname as function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgname = 'on_auth_user_created';

-- 2. 最近の登録で紹介リンクが機能しているかチェック
SELECT 
    'referral_link_test' as check_type,
    u.user_id,
    u.email,
    u.referrer_user_id,
    r.email as referrer_email,
    au.raw_user_meta_data->>'referrer_user_id' as original_referrer_meta,
    u.created_at,
    CASE 
        WHEN u.referrer_user_id IS NOT NULL AND r.user_id IS NOT NULL THEN '✅ 紹介リンク正常'
        WHEN u.referrer_user_id IS NOT NULL AND r.user_id IS NULL THEN '⚠️ 紹介者不明'
        WHEN au.raw_user_meta_data->>'referrer_user_id' IS NOT NULL AND u.referrer_user_id IS NULL THEN '❌ 紹介情報未同期'
        ELSE '⚪ 直接登録'
    END as referral_status
FROM users u
LEFT JOIN users r ON u.referrer_user_id = r.user_id
JOIN auth.users au ON u.id = au.id
WHERE u.created_at >= NOW() - INTERVAL '48 hours'
ORDER BY u.created_at DESC;

-- 3. 紹介システムの全体統計
SELECT 
    'referral_system_stats' as check_type,
    'Total Users' as metric,
    COUNT(*) as value
FROM users
UNION ALL
SELECT 
    'referral_system_stats' as check_type,
    'Users with Referrer' as metric,
    COUNT(*) as value
FROM users WHERE referrer_user_id IS NOT NULL
UNION ALL
SELECT 
    'referral_system_stats' as check_type,
    'Users with CoinW UID' as metric,
    COUNT(*) as value
FROM users WHERE coinw_uid IS NOT NULL
UNION ALL
SELECT 
    'referral_system_stats' as check_type,
    'Recent Registrations (24h)' as metric,
    COUNT(*) as value
FROM users WHERE created_at >= NOW() - INTERVAL '24 hours';
