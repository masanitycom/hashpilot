-- 正しいユーザーデータの復元

-- 1. auth.usersテーブルから元の登録情報を確認
SELECT 
    'auth_users_check' as check_type,
    id,
    email,
    raw_user_meta_data,
    user_metadata,
    created_at,
    email_confirmed_at
FROM auth.users
WHERE id IN (
    SELECT id FROM users WHERE user_id IN ('2C44D5', 'DE5328', '466809', '794682')
)
ORDER BY created_at DESC;

-- 2. 他の正常なユーザーの登録パターンを確認
SELECT 
    'normal_users_pattern' as check_type,
    u.user_id,
    u.email,
    u.coinw_uid,
    u.referrer_user_id,
    au.raw_user_meta_data,
    u.created_at
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.coinw_uid IS NOT NULL
AND u.created_at >= '2025-07-01'
ORDER BY u.created_at DESC
LIMIT 5;

-- 3. 登録時のメタデータパターンの比較
SELECT 
    'metadata_comparison' as check_type,
    'problem_users' as user_type,
    COUNT(*) as count,
    array_agg(DISTINCT jsonb_object_keys(au.raw_user_meta_data)) as metadata_keys
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.user_id IN ('2C44D5', 'DE5328', '466809', '794682')

UNION ALL

SELECT 
    'metadata_comparison' as check_type,
    'normal_users' as user_type,
    COUNT(*) as count,
    array_agg(DISTINCT jsonb_object_keys(au.raw_user_meta_data)) as metadata_keys
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.coinw_uid IS NOT NULL
AND u.created_at >= '2025-07-01';
