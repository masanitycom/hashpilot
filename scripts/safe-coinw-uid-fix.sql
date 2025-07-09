-- 安全なCoinW UID修正スクリプト

-- 1. 修正前の状況確認
SELECT 
    'before_fix' as status,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    created_at
FROM users 
WHERE coinw_uid IS NULL
ORDER BY created_at DESC;

-- 2. 各ユーザーの元の登録情報を確認
SELECT 
    'original_registration_data' as check_type,
    u.user_id,
    u.email,
    au.raw_user_meta_data,
    au.raw_user_meta_data->>'coinw_uid' as meta_coinw,
    au.raw_user_meta_data->>'referrer_user_id' as meta_referrer,
    u.created_at
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.coinw_uid IS NULL
ORDER BY u.created_at DESC;

-- 3. 安全な修正（実際の値を入力してから実行）

-- tmtm1108tmtm@gmail.com (2C44D5)
-- 実際のCoinW UID: [ここに入力]
-- 実際の紹介者: [ここに入力]
/*
UPDATE users SET 
    coinw_uid = '実際のCoinW_UID',
    referrer_user_id = '実際の紹介者ID',
    updated_at = NOW()
WHERE user_id = '2C44D5' AND email = 'tmtm1108tmtm@gmail.com';
*/

-- oshiboriakihiro@gmail.com (DE5328)
-- 実際のCoinW UID: [ここに入力]
-- 実際の紹介者: [ここに入力]
/*
UPDATE users SET 
    coinw_uid = '実際のCoinW_UID',
    referrer_user_id = '実際の紹介者ID',
    updated_at = NOW()
WHERE user_id = 'DE5328' AND email = 'oshiboriakihiro@gmail.com';
*/

-- soccergurataku@gmail.com (466809)
-- 実際のCoinW UID: [ここに入力]
-- 実際の紹介者: [ここに入力]
/*
UPDATE users SET 
    coinw_uid = '実際のCoinW_UID',
    referrer_user_id = '実際の紹介者ID',
    updated_at = NOW()
WHERE user_id = '466809' AND email = 'soccergurataku@gmail.com';
*/

-- tamakimining@gmail.com (794682)
-- 実際のCoinW UID: [ここに入力]
-- 実際の紹介者: [ここに入力]
/*
UPDATE users SET 
    coinw_uid = '実際のCoinW_UID',
    referrer_user_id = '実際の紹介者ID',
    updated_at = NOW()
WHERE user_id = '794682' AND email = 'tamakimining@gmail.com';
*/

-- 新しいユーザー (7A9637)
-- 実際のCoinW UID: [ここに入力]
-- 実際の紹介者: [ここに入力]
/*
UPDATE users SET 
    coinw_uid = '実際のCoinW_UID',
    referrer_user_id = '実際の紹介者ID',
    updated_at = NOW()
WHERE user_id = '7A9637';
*/

-- 4. 修正後の確認
SELECT 
    'after_fix' as status,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    updated_at,
    CASE 
        WHEN coinw_uid IS NOT NULL THEN '✅ CoinW UID設定済み'
        ELSE '❌ CoinW UID未設定'
    END as coinw_status,
    CASE 
        WHEN referrer_user_id IS NOT NULL THEN '✅ 紹介者設定済み'
        ELSE '⚪ 紹介者なし'
    END as referrer_status
FROM users 
WHERE user_id IN ('2C44D5', 'DE5328', '466809', '794682', '7A9637')
ORDER BY updated_at DESC;

-- 5. 紹介者の存在確認
SELECT 
    'referrer_validation' as check_type,
    u.user_id,
    u.email,
    u.referrer_user_id,
    r.user_id as referrer_exists,
    r.email as referrer_email,
    CASE 
        WHEN r.user_id IS NOT NULL THEN '✅ 紹介者存在'
        WHEN u.referrer_user_id IS NULL THEN '⚪ 紹介者なし'
        ELSE '❌ 紹介者不明'
    END as referrer_status
FROM users u
LEFT JOIN users r ON u.referrer_user_id = r.user_id
WHERE u.user_id IN ('2C44D5', 'DE5328', '466809', '794682', '7A9637');
