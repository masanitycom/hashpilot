-- 登録システムの問題を詳細調査（修正版）

-- 1. 正常なユーザーと問題のあるユーザーの比較
SELECT 
    'registration_comparison' as check_type,
    u.user_id,
    u.email,
    u.created_at,
    au.raw_user_meta_data,
    CASE 
        WHEN au.raw_user_meta_data IS NULL THEN '❌ メタデータなし'
        WHEN au.raw_user_meta_data = '{}' THEN '❌ 空のメタデータ'
        WHEN au.raw_user_meta_data->>'coinw_uid' IS NULL THEN '⚠️ CoinW UID欠如'
        ELSE '✅ 正常'
    END as registration_status,
    au.raw_user_meta_data->>'coinw_uid' as meta_coinw,
    au.raw_user_meta_data->>'referrer_user_id' as meta_referrer,
    au.raw_user_meta_data->>'registration_source' as registration_source
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.created_at >= '2025-06-20'
ORDER BY u.created_at DESC;

-- 2. 登録時期による問題の分析
SELECT 
    'registration_timeline' as analysis_type,
    DATE(u.created_at) as registration_date,
    COUNT(*) as total_registrations,
    COUNT(CASE WHEN au.raw_user_meta_data IS NULL OR au.raw_user_meta_data = '{}' THEN 1 END) as failed_registrations,
    COUNT(CASE WHEN au.raw_user_meta_data->>'coinw_uid' IS NOT NULL THEN 1 END) as successful_registrations,
    ROUND(
        COUNT(CASE WHEN au.raw_user_meta_data->>'coinw_uid' IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 
        2
    ) as success_rate
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.created_at >= '2025-06-01'
GROUP BY DATE(u.created_at)
ORDER BY registration_date DESC;

-- 3. 現在のトリガー状況（修正版）
SELECT 
    'trigger_status' as check_type,
    schemaname,
    tablename,
    tgname as triggername,
    tgenabled,
    tgtype
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE tgname = 'on_auth_user_created';

-- 4. 最近の認証ユーザー作成ログ
SELECT 
    'recent_auth_users' as check_type,
    id,
    email,
    created_at,
    email_confirmed_at,
    raw_user_meta_data,
    CASE 
        WHEN raw_user_meta_data IS NULL THEN '❌ メタデータなし'
        WHEN raw_user_meta_data = '{}' THEN '❌ 空のメタデータ'
        ELSE '✅ メタデータあり'
    END as metadata_status
FROM auth.users 
WHERE created_at >= '2025-06-20'
ORDER BY created_at DESC;

-- 5. 問題のあるユーザーの詳細分析
SELECT 
    'problem_users_analysis' as check_type,
    u.user_id,
    u.email,
    u.created_at,
    au.id as auth_id,
    au.email_confirmed_at,
    au.last_sign_in_at,
    au.raw_user_meta_data,
    CASE 
        WHEN au.email_confirmed_at IS NULL THEN '❌ メール未確認'
        WHEN au.last_sign_in_at IS NULL THEN '⚠️ 未ログイン'
        ELSE '✅ アクティブ'
    END as user_status
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.coinw_uid IS NULL
ORDER BY u.created_at DESC;

-- 6. 関数の存在確認
SELECT 
    'function_check' as check_type,
    proname as function_name,
    prosrc as function_body
FROM pg_proc 
WHERE proname = 'handle_new_user';
