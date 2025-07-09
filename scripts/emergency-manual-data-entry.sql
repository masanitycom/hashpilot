-- 緊急手動データ入力（実際の値を入力してください）

-- 注意: 実際のCoinW UIDと紹介者情報を入力してから実行してください

-- 1. 修正前の確認
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

-- 2. 手動データ入力テンプレート
-- 以下のコメントアウトを外して、実際の値を入力してください

-- tmtm1108tmtm@gmail.com (2C44D5) - 2025-07-06 07:38:34 【今日登録・緊急】
-- 実際のCoinW UID: [ここに入力してください]
-- 実際の紹介者: [ここに入力してください]
/*
UPDATE users SET 
    coinw_uid = '実際のCoinW_UID_1',
    referrer_user_id = '実際の紹介者ID_1',
    updated_at = NOW()
WHERE user_id = '2C44D5' AND email = 'tmtm1108tmtm@gmail.com';

UPDATE auth.users SET 
    raw_user_meta_data = jsonb_build_object(
        'coinw_uid', '実際のCoinW_UID_1',
        'referrer_user_id', '実際の紹介者ID_1',
        'registration_source', 'manual_emergency_fix',
        'fixed_at', NOW()::text,
        'original_registration_date', '2025-07-06T07:38:34.547167+00:00'
    )
WHERE email = 'tmtm1108tmtm@gmail.com';
*/

-- oshiboriakihiro@gmail.com (DE5328) - 2025-07-06 07:30:31 【今日登録・緊急】
-- 実際のCoinW UID: [ここに入力してください]
-- 実際の紹介者: [ここに入力してください]
/*
UPDATE users SET 
    coinw_uid = '実際のCoinW_UID_2',
    referrer_user_id = '実際の紹介者ID_2',
    updated_at = NOW()
WHERE user_id = 'DE5328' AND email = 'oshiboriakihiro@gmail.com';

UPDATE auth.users SET 
    raw_user_meta_data = jsonb_build_object(
        'coinw_uid', '実際のCoinW_UID_2',
        'referrer_user_id', '実際の紹介者ID_2',
        'registration_source', 'manual_emergency_fix',
        'fixed_at', NOW()::text,
        'original_registration_date', '2025-07-06T07:30:31.95947+00:00'
    )
WHERE email = 'oshiboriakihiro@gmail.com';
*/

-- soccergurataku@gmail.com (466809) - 2025-07-06 07:04:20 【今日登録・緊急】
-- 実際のCoinW UID: [ここに入力してください]
-- 実際の紹介者: [ここに入力してください]
/*
UPDATE users SET 
    coinw_uid = '実際のCoinW_UID_3',
    referrer_user_id = '実際の紹介者ID_3',
    updated_at = NOW()
WHERE user_id = '466809' AND email = 'soccergurataku@gmail.com';

UPDATE auth.users SET 
    raw_user_meta_data = jsonb_build_object(
        'coinw_uid', '実際のCoinW_UID_3',
        'referrer_user_id', '実際の紹介者ID_3',
        'registration_source', 'manual_emergency_fix',
        'fixed_at', NOW()::text,
        'original_registration_date', '2025-07-06T07:04:20.645621+00:00'
    )
WHERE email = 'soccergurataku@gmail.com';
*/

-- tamakimining@gmail.com (794682) - 2025-07-05 09:09:47 【昨日登録・早急】
-- 実際のCoinW UID: [ここに入力してください]
-- 実際の紹介者: [ここに入力してください]
/*
UPDATE users SET 
    coinw_uid = '実際のCoinW_UID_4',
    referrer_user_id = '実際の紹介者ID_4',
    updated_at = NOW()
WHERE user_id = '794682' AND email = 'tamakimining@gmail.com';

UPDATE auth.users SET 
    raw_user_meta_data = jsonb_build_object(
        'coinw_uid', '実際のCoinW_UID_4',
        'referrer_user_id', '実際の紹介者ID_4',
        'registration_source', 'manual_emergency_fix',
        'fixed_at', NOW()::text,
        'original_registration_date', '2025-07-05T09:09:47.038524+00:00'
    )
WHERE email = 'tamakimining@gmail.com';
*/

-- masakuma1108@gmail.com (7A9637) - 2025-06-21 12:21:13 【通常対応】
-- 実際のCoinW UID: [ここに入力してください]
-- 実際の紹介者: [ここに入力してください]
/*
UPDATE users SET 
    coinw_uid = '実際のCoinW_UID_5',
    referrer_user_id = '実際の紹介者ID_5',
    updated_at = NOW()
WHERE user_id = '7A9637' AND email = 'masakuma1108@gmail.com';

UPDATE auth.users SET 
    raw_user_meta_data = jsonb_build_object(
        'coinw_uid', '実際のCoinW_UID_5',
        'referrer_user_id', '実際の紹介者ID_5',
        'registration_source', 'manual_emergency_fix',
        'fixed_at', NOW()::text,
        'original_registration_date', '2025-06-21T12:21:13.155661+00:00'
    )
WHERE email = 'masakuma1108@gmail.com';
*/

-- 3. 修正後の確認
SELECT 
    'after_manual_fix' as status,
    u.user_id,
    u.email,
    u.coinw_uid,
    u.referrer_user_id,
    u.updated_at,
    au.raw_user_meta_data,
    CASE 
        WHEN u.coinw_uid IS NOT NULL THEN '✅ 修正完了'
        ELSE '❌ 未修正'
    END as fix_status
FROM users u
JOIN auth.users au ON u.id = au.id
WHERE u.user_id IN ('2C44D5', 'DE5328', '466809', '794682', '7A9637')
ORDER BY u.updated_at DESC;

-- 4. 紹介者の存在確認
SELECT 
    'referrer_validation_after_fix' as check_type,
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

-- 5. 緊急対応完了の確認
SELECT 
    'emergency_fix_summary' as report_type,
    COUNT(*) as total_problem_users,
    COUNT(CASE WHEN coinw_uid IS NOT NULL THEN 1 END) as fixed_users,
    COUNT(CASE WHEN coinw_uid IS NULL THEN 1 END) as remaining_issues,
    CASE 
        WHEN COUNT(CASE WHEN coinw_uid IS NULL THEN 1 END) = 0 THEN '✅ 全て修正完了'
        ELSE '❌ 未修正あり'
    END as status
FROM users 
WHERE user_id IN ('2C44D5', 'DE5328', '466809', '794682', '7A9637');
