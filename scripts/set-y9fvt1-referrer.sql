UPDATE users 
SET referrer_user_id = '7A9637'
WHERE user_id = 'Y9FVT1';

-- 結果確認
SELECT 
    user_id,
    email,
    referrer_user_id,
    '設定完了' as status
FROM users 
WHERE user_id = 'Y9FVT1';

-- 紹介関係確認
SELECT 
    '紹介者' as relation,
    user_id,
    email
FROM users 
WHERE user_id = '7A9637'
UNION ALL
SELECT 
    '被紹介者' as relation,
    user_id,
    email
FROM users 
WHERE user_id = 'Y9FVT1';
