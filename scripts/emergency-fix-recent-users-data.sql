-- 最近のユーザーの登録データを緊急調査・修正

-- 1. 問題のある4人のユーザーの詳細調査
SELECT 
    'registration_investigation' as check_type,
    u.user_id,
    u.email,
    u.referrer_user_id,
    u.coinw_uid,
    au.raw_user_meta_data,
    u.created_at
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.user_id IN ('2C44D5', 'DE5328', '466809', '794682')
ORDER BY u.created_at DESC;

-- 2. ダミーのCoinW UIDを削除（もし設定されていた場合）
UPDATE users 
SET 
    coinw_uid = NULL,
    updated_at = NOW()
WHERE user_id IN ('2C44D5', 'DE5328', '466809', '794682')
AND coinw_uid LIKE 'COINW_UID_FOR_%';

-- 3. 修正後の状態確認
SELECT 
    'after_restoration' as status,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    created_at,
    CASE 
        WHEN coinw_uid IS NOT NULL THEN '✅ CoinW UID設定済み'
        ELSE '❌ CoinW UID未設定'
    END as coinw_status,
    CASE 
        WHEN referrer_user_id IS NOT NULL THEN '✅ 紹介者設定済み'
        ELSE '❌ 紹介者未設定'
    END as referrer_status
FROM users 
WHERE user_id IN ('2C44D5', 'DE5328', '466809', '794682')
ORDER BY created_at DESC;

-- 4. 全体のCoinW UID設定状況
SELECT 
    'coinw_uid_status' as check_type,
    CASE 
        WHEN coinw_uid IS NULL THEN 'CoinW UID未設定'
        ELSE 'CoinW UID設定済み'
    END as status,
    COUNT(*) as count,
    array_agg(user_id ORDER BY created_at DESC) as user_ids
FROM users
GROUP BY (coinw_uid IS NULL)
ORDER BY status;
