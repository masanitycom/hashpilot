-- 残りのCoinW UID未設定ユーザーの確認

SELECT 
    'Remaining Users Without CoinW UID' as check_type,
    user_id,
    email,
    referrer_user_id,
    CASE 
        WHEN referrer_user_id IS NOT NULL THEN '紹介経由'
        ELSE '直接登録'
    END as registration_type,
    created_at
FROM users 
WHERE coinw_uid IS NULL
ORDER BY created_at DESC;

-- 管理者向け: 各ユーザーの登録時メタデータ確認
SELECT 
    'User Metadata Check' as check_type,
    u.user_id,
    u.email,
    au.raw_user_meta_data->>'coinw_uid' as metadata_coinw_uid,
    au.raw_user_meta_data->>'referrer_user_id' as metadata_referrer,
    u.coinw_uid as current_coinw_uid,
    u.referrer_user_id as current_referrer
FROM users u
LEFT JOIN auth.users au ON u.id = au.id
WHERE u.coinw_uid IS NULL;
