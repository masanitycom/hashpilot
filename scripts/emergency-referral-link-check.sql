-- 緊急：紹介リンクの動作確認

-- 1. 最新の登録状況（過去24時間）
SELECT 
    'recent_registrations' as check_type,
    u.user_id,
    u.email,
    u.referrer_user_id,
    u.coinw_uid,
    u.created_at,
    CASE 
        WHEN u.referrer_user_id IS NOT NULL THEN '✅ 紹介者あり'
        ELSE '❌ 紹介者なし'
    END as referral_status,
    CASE 
        WHEN u.coinw_uid IS NOT NULL THEN '✅ CoinW UID設定済み'
        ELSE '❌ CoinW UID未設定'
    END as coinw_status
FROM users u
WHERE u.created_at >= NOW() - INTERVAL '24 hours'
ORDER BY u.created_at DESC;

-- 2. 紹介リンクの使用実績（過去1週間）
SELECT 
    'referral_usage_week' as check_type,
    u.referrer_user_id,
    r.email as referrer_email,
    COUNT(*) as referral_count,
    array_agg(u.user_id ORDER BY u.created_at DESC) as referred_users,
    MAX(u.created_at) as latest_referral
FROM users u
LEFT JOIN users r ON u.referrer_user_id = r.user_id
WHERE u.referrer_user_id IS NOT NULL 
    AND u.created_at >= NOW() - INTERVAL '7 days'
GROUP BY u.referrer_user_id, r.email
ORDER BY referral_count DESC;

-- 3. 登録フォームの問題を特定
SELECT 
    'registration_metadata_check' as check_type,
    u.user_id,
    u.email,
    au.raw_user_meta_data,
    au.raw_user_meta_data->>'referrer_user_id' as meta_referrer,
    au.raw_user_meta_data->>'coinw_uid' as meta_coinw,
    au.raw_user_meta_data->>'registration_source' as source,
    u.created_at
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.created_at >= NOW() - INTERVAL '24 hours'
ORDER BY u.created_at DESC;

-- 4. 全体の紹介システム状況
SELECT 
    'overall_referral_system' as check_type,
    COUNT(*) as total_users,
    COUNT(CASE WHEN referrer_user_id IS NOT NULL THEN 1 END) as users_with_referrer,
    COUNT(CASE WHEN coinw_uid IS NOT NULL THEN 1 END) as users_with_coinw,
    ROUND(
        COUNT(CASE WHEN referrer_user_id IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 
        2
    ) as referral_percentage,
    ROUND(
        COUNT(CASE WHEN coinw_uid IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 
        2
    ) as coinw_percentage
FROM users;
