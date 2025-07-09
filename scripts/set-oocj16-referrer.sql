-- OOCJ16ユーザーの紹介者を7A9637に設定
UPDATE users 
SET referrer_user_id = '7A9637'
WHERE user_id = 'OOCJ16';

-- 結果確認
SELECT 
    user_id,
    email,
    referrer_user_id,
    coinw_uid,
    created_at
FROM users 
WHERE user_id IN ('OOCJ16', '7A9637')
ORDER BY user_id;

-- 紹介関係確認
SELECT 
    '紹介者' as relation,
    user_id,
    email,
    coinw_uid
FROM users 
WHERE user_id = '7A9637'

UNION ALL

SELECT 
    '被紹介者' as relation,
    user_id,
    email,
    coinw_uid
FROM users 
WHERE user_id = 'OOCJ16';
