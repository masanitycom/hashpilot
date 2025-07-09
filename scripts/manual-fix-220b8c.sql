-- 220B8Cユーザーの手動修正
-- 実際のCoinW UIDと紹介者IDを入力してください

UPDATE users 
SET 
    coinw_uid = 'ACTUAL_COINW_UID_HERE',  -- 実際のCoinW UIDに置き換え
    referrer_user_id = 'ACTUAL_REFERRER_ID_HERE',  -- 実際の紹介者IDに置き換え（なければNULL）
    updated_at = NOW()
WHERE user_id = '220B8C';

-- 修正結果確認
SELECT 
    'fix_result' as status,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    updated_at
FROM users 
WHERE user_id = '220B8C';

-- 全体統計更新
SELECT 
    'updated_stats' as check_type,
    COUNT(*) as total_users,
    COUNT(coinw_uid) as users_with_coinw,
    COUNT(referrer_user_id) as users_with_referrer,
    ROUND(COUNT(coinw_uid) * 100.0 / COUNT(*), 2) as coinw_percentage,
    ROUND(COUNT(referrer_user_id) * 100.0 / COUNT(*), 2) as referrer_percentage
FROM users;
