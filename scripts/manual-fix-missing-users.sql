-- 手動で不足データを修正
-- 実際のCoinW UIDを入力してから実行してください

-- 問題のある5人のユーザーの現在の状態を確認
SELECT 
    'before_manual_fix' as status,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    created_at
FROM users 
WHERE user_id IN ('2C44D5', 'DE5328', '466809', '794682', '7A9637')
ORDER BY created_at DESC;

-- 以下のUPDATE文の 'COINW_UID_HERE' と 'REFERRER_ID_HERE' を実際の値に置き換えてください

-- 1. tmtm1108tmtm@gmail.com (2C44D5) - 2025-07-06 07:38登録
-- UPDATE users 
-- SET 
--     coinw_uid = 'COINW_UID_HERE',  -- 実際のCoinW UIDに置き換え
--     referrer_user_id = 'REFERRER_ID_HERE',  -- 紹介者IDがあれば入力（なければNULLのまま）
--     updated_at = NOW()
-- WHERE user_id = '2C44D5';

-- 2. oshiboriakihiro@gmail.com (DE5328) - 2025-07-06 07:30登録
-- UPDATE users 
-- SET 
--     coinw_uid = 'COINW_UID_HERE',  -- 実際のCoinW UIDに置き換え
--     referrer_user_id = 'REFERRER_ID_HERE',  -- 紹介者IDがあれば入力（なければNULLのまま）
--     updated_at = NOW()
-- WHERE user_id = 'DE5328';

-- 3. soccergurataku@gmail.com (466809) - 2025-07-06 07:04登録
-- UPDATE users 
-- SET 
--     coinw_uid = 'COINW_UID_HERE',  -- 実際のCoinW UIDに置き換え
--     referrer_user_id = 'REFERRER_ID_HERE',  -- 紹介者IDがあれば入力（なければNULLのまま）
--     updated_at = NOW()
-- WHERE user_id = '466809';

-- 4. tamakimining@gmail.com (794682) - 2025-07-05 09:09登録
-- UPDATE users 
-- SET 
--     coinw_uid = 'COINW_UID_HERE',  -- 実際のCoinW UIDに置き換え
--     referrer_user_id = 'REFERRER_ID_HERE',  -- 紹介者IDがあれば入力（なければNULLのまま）
--     updated_at = NOW()
-- WHERE user_id = '794682';

-- 5. masakuma1108@gmail.com (7A9637) - 2025-06-21 12:21登録
-- UPDATE users 
-- SET 
--     coinw_uid = 'COINW_UID_HERE',  -- 実際のCoinW UIDに置き換え
--     referrer_user_id = 'REFERRER_ID_HERE',  -- 紹介者IDがあれば入力（なければNULLのまま）
--     updated_at = NOW()
-- WHERE user_id = '7A9637';

-- 修正後の確認
SELECT 
    'after_manual_fix' as status,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    updated_at
FROM users 
WHERE user_id IN ('2C44D5', 'DE5328', '466809', '794682', '7A9637')
ORDER BY updated_at DESC;

-- 全体の統計確認
SELECT 
    'final_system_stats' as check_type,
    COUNT(*) as total_users,
    COUNT(coinw_uid) as users_with_coinw_uid,
    COUNT(referrer_user_id) as users_with_referrer,
    ROUND(COUNT(coinw_uid) * 100.0 / COUNT(*), 2) as coinw_percentage,
    ROUND(COUNT(referrer_user_id) * 100.0 / COUNT(*), 2) as referral_percentage
FROM users;
