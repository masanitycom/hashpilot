-- 紹介リンクの動作確認

-- 1. 紹介システムの基本機能確認
SELECT 
    'referral_system_check' as check_type,
    COUNT(*) as total_users,
    COUNT(referrer_user_id) as users_with_referrer,
    ROUND(COUNT(referrer_user_id) * 100.0 / COUNT(*), 2) as referral_percentage
FROM users;

-- 2. 最近の紹介関係を確認
SELECT 
    'recent_referrals' as check_type,
    u1.user_id as referred_user,
    u1.email as referred_email,
    u1.referrer_user_id,
    u2.email as referrer_email,
    u1.created_at
FROM users u1
LEFT JOIN users u2 ON u1.referrer_user_id = u2.user_id
WHERE u1.referrer_user_id IS NOT NULL
ORDER BY u1.created_at DESC
LIMIT 10;

-- 3. 紹介トリガーの状態確認
SELECT 
    'trigger_status' as check_type,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'on_auth_user_created';

-- 4. 利用可能な紹介リンクを生成
SELECT 
    'available_referral_links' as check_type,
    user_id,
    email,
    coinw_uid,
    CONCAT('https://your-domain.com/pre-register?ref=', user_id) as referral_link
FROM users 
WHERE coinw_uid IS NOT NULL 
    AND is_active = true
ORDER BY created_at DESC
LIMIT 5;

SELECT 'referral_link_test_complete' as status, NOW() as timestamp;
