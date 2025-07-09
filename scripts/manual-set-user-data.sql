-- 手動でユーザーデータを設定するスクリプト
-- 実際のCoinW UIDと紹介者情報を入力してください

-- 注意: 実際の値を入力してから実行してください

-- ユーザー: tmtm1108tmtm@gmail.com (2C44D5)
-- UPDATE users 
-- SET 
--     coinw_uid = '実際のCoinW_UID',
--     referrer_user_id = '実際の紹介者ID',
--     updated_at = NOW()
-- WHERE user_id = '2C44D5';

-- ユーザー: oshiboriakihiro@gmail.com (DE5328)
-- UPDATE users 
-- SET 
--     coinw_uid = '実際のCoinW_UID',
--     referrer_user_id = '実際の紹介者ID',
--     updated_at = NOW()
-- WHERE user_id = 'DE5328';

-- ユーザー: soccergurataku@gmail.com (466809)
-- UPDATE users 
-- SET 
--     coinw_uid = '実際のCoinW_UID',
--     referrer_user_id = '実際の紹介者ID',
--     updated_at = NOW()
-- WHERE user_id = '466809';

-- ユーザー: tamakimining@gmail.com (794682)
-- UPDATE users 
-- SET 
--     coinw_uid = '実際のCoinW_UID',
--     referrer_user_id = '実際の紹介者ID',
--     updated_at = NOW()
-- WHERE user_id = '794682';

-- 設定後の確認
SELECT 
    'manual_update_result' as status,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    updated_at
FROM users 
WHERE user_id IN ('2C44D5', 'DE5328', '466809', '794682')
ORDER BY updated_at DESC;

-- 紹介者の確認（設定した紹介者IDが実在するかチェック）
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
WHERE u.user_id IN ('2C44D5', 'DE5328', '466809', '794682');
