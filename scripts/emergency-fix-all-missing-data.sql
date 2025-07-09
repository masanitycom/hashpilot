-- 緊急：すべての未設定データを修正

-- 1. 現在未設定のユーザーを確認
SELECT 
    'users_needing_fix' as status,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    created_at
FROM users 
WHERE coinw_uid IS NULL 
ORDER BY created_at DESC;

-- 2. 各ユーザーの実際の登録情報を確認
SELECT 
    'registration_details' as check_type,
    u.user_id,
    u.email,
    au.raw_user_meta_data,
    u.created_at
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.coinw_uid IS NULL
ORDER BY u.created_at DESC;

-- 3. 手動設定用のテンプレート（実際の値を入力してください）
/*
-- ユーザー別設定（実際の値に置き換えてください）

-- tmtm1108tmtm@gmail.com (2C44D5)
UPDATE users SET 
    coinw_uid = '実際のCoinW_UID_1',
    referrer_user_id = '実際の紹介者ID_1',
    updated_at = NOW()
WHERE user_id = '2C44D5';

-- oshiboriakihiro@gmail.com (DE5328)
UPDATE users SET 
    coinw_uid = '実際のCoinW_UID_2',
    referrer_user_id = '実際の紹介者ID_2',
    updated_at = NOW()
WHERE user_id = 'DE5328';

-- soccergurataku@gmail.com (466809)
UPDATE users SET 
    coinw_uid = '実際のCoinW_UID_3',
    referrer_user_id = '実際の紹介者ID_3',
    updated_at = NOW()
WHERE user_id = '466809';

-- tamakimining@gmail.com (794682)
UPDATE users SET 
    coinw_uid = '実際のCoinW_UID_4',
    referrer_user_id = '実際の紹介者ID_4',
    updated_at = NOW()
WHERE user_id = '794682';

-- 新しいユーザー (7A9637)
UPDATE users SET 
    coinw_uid = '実際のCoinW_UID_5',
    referrer_user_id = '実際の紹介者ID_5',
    updated_at = NOW()
WHERE user_id = '7A9637';
*/

-- 4. 設定後の確認
SELECT 
    'final_verification' as status,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    updated_at
FROM users 
WHERE user_id IN ('2C44D5', 'DE5328', '466809', '794682', '7A9637')
ORDER BY updated_at DESC;
