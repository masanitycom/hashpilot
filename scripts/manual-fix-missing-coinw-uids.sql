-- 4人のユーザーのCoinW UIDを手動設定

-- 実際のCoinW UIDを調べて以下を編集してください

-- 1. tmtm1108tmtm@gmail.com (2C44D5)
UPDATE users 
SET coinw_uid = 'ACTUAL_COINW_UID_HERE', updated_at = NOW()
WHERE user_id = '2C44D5';

-- 2. oshiboriakihiro@gmail.com (DE5328)
UPDATE users 
SET coinw_uid = 'ACTUAL_COINW_UID_HERE', updated_at = NOW()
WHERE user_id = 'DE5328';

-- 3. soccergurataku@gmail.com (466809)
UPDATE users 
SET coinw_uid = 'ACTUAL_COINW_UID_HERE', updated_at = NOW()
WHERE user_id = '466809';

-- 4. tamakimining@gmail.com (794682)
UPDATE users 
SET coinw_uid = 'ACTUAL_COINW_UID_HERE', updated_at = NOW()
WHERE user_id = '794682';

-- 5. 確認
SELECT 
    user_id,
    email,
    coinw_uid,
    referrer_user_id
FROM users 
WHERE coinw_uid IS NULL
ORDER BY created_at DESC;

-- 6. 最終統計
SELECT 
    COUNT(*) as total_users,
    COUNT(coinw_uid) as users_with_coinw,
    COUNT(referrer_user_id) as users_with_referrer,
    ROUND(COUNT(coinw_uid) * 100.0 / COUNT(*), 2) as coinw_percentage,
    ROUND(COUNT(referrer_user_id) * 100.0 / COUNT(*), 2) as referrer_percentage
FROM users;
