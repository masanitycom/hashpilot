-- 特定のユーザーのCoinW UIDを設定
-- 実際の値を入力してから実行してください

-- 現在の状況確認
SELECT 
    'current_status' as check_type,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    created_at
FROM users 
WHERE user_id IN ('2C44D5', 'DE5328', '466809', '794682')
ORDER BY created_at DESC;

-- 実際のCoinW UIDを設定（コメントアウトを解除して実際の値を入力）

-- tmtm1108tmtm@gmail.com (2C44D5)
-- UPDATE users SET coinw_uid = '実際のCoinW_UID', updated_at = NOW() WHERE user_id = '2C44D5';

-- oshiboriakihiro@gmail.com (DE5328)  
-- UPDATE users SET coinw_uid = '実際のCoinW_UID', updated_at = NOW() WHERE user_id = 'DE5328';

-- soccergurataku@gmail.com (466809)
-- UPDATE users SET coinw_uid = '実際のCoinW_UID', updated_at = NOW() WHERE user_id = '466809';

-- tamakimining@gmail.com (794682)
-- UPDATE users SET coinw_uid = '実際のCoinW_UID', updated_at = NOW() WHERE user_id = '794682';

-- 紹介者情報も設定する場合（コメントアウトを解除して実際の値を入力）

-- tmtm1108tmtm@gmail.com (2C44D5) - 紹介者設定
-- UPDATE users SET referrer_user_id = '実際の紹介者ID', updated_at = NOW() WHERE user_id = '2C44D5';

-- oshiboriakihiro@gmail.com (DE5328) - 紹介者設定
-- UPDATE users SET referrer_user_id = '実際の紹介者ID', updated_at = NOW() WHERE user_id = 'DE5328';

-- soccergurataku@gmail.com (466809) - 紹介者設定
-- UPDATE users SET referrer_user_id = '実際の紹介者ID', updated_at = NOW() WHERE user_id = '466809';

-- tamakimining@gmail.com (794682) - 紹介者設定
-- UPDATE users SET referrer_user_id = '実際の紹介者ID', updated_at = NOW() WHERE user_id = '794682';

-- 設定後の確認
SELECT 
    'after_update' as check_type,
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
WHERE user_id IN ('2C44D5', 'DE5328', '466809', '794682')
ORDER BY updated_at DESC;
