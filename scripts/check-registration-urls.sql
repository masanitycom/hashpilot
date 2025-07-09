-- 登録URLとパラメータの調査

-- 1. 最近の登録者の詳細メタデータ確認
SELECT 
    'detailed_metadata_check' as check_type,
    u.user_id,
    u.email,
    u.created_at,
    au.raw_user_meta_data,
    au.user_metadata,
    -- メタデータから個別キーを抽出
    au.raw_user_meta_data->>'referrer_user_id' as meta_referrer,
    au.raw_user_meta_data->>'coinw_uid' as meta_coinw,
    au.raw_user_meta_data->>'registration_source' as meta_source,
    au.raw_user_meta_data->>'registration_timestamp' as meta_timestamp
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.user_id IN ('2C44D5', 'DE5328', '466809', '794682')
ORDER BY u.created_at DESC;

-- 2. 正常なユーザーとの比較
SELECT 
    'normal_user_metadata' as check_type,
    u.user_id,
    u.email,
    u.coinw_uid,
    u.referrer_user_id,
    au.raw_user_meta_data->>'referrer_user_id' as meta_referrer,
    au.raw_user_meta_data->>'coinw_uid' as meta_coinw,
    au.raw_user_meta_data->>'registration_source' as meta_source,
    u.created_at
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.coinw_uid IS NOT NULL
AND u.created_at >= '2025-07-01'
ORDER BY u.created_at DESC
LIMIT 3;

-- 3. 登録フォームの問題を特定
SELECT 
    'registration_issue_analysis' as check_type,
    CASE 
        WHEN au.raw_user_meta_data ? 'referrer_user_id' THEN 'referrer_key_exists'
        ELSE 'referrer_key_missing'
    END as referrer_key_status,
    CASE 
        WHEN au.raw_user_meta_data ? 'coinw_uid' THEN 'coinw_key_exists'
        ELSE 'coinw_key_missing'
    END as coinw_key_status,
    COUNT(*) as count
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.user_id IN ('2C44D5', 'DE5328', '466809', '794682')
GROUP BY 
    (au.raw_user_meta_data ? 'referrer_user_id'),
    (au.raw_user_meta_data ? 'coinw_uid');
