-- データ不整合の緊急修正

-- 1. Y9FVT1の紹介者情報を正しく設定
UPDATE users 
SET referrer_user_id = '2BF53B'
WHERE user_id = 'Y9FVT1' AND email = 'torucajino@gmail.com';

-- 2. 紹介リンクから登録したユーザーのCoinW UIDを復旧
-- (auth.usersのメタデータから取得)
DO $$
DECLARE
    user_record RECORD;
    coinw_from_meta TEXT;
    referrer_from_meta TEXT;
BEGIN
    -- auth.usersからメタデータを取得して復旧
    FOR user_record IN 
        SELECT au.id, au.email, au.raw_user_meta_data, u.user_id, u.coinw_uid, u.referrer_user_id
        FROM auth.users au
        LEFT JOIN users u ON au.id = u.id
        WHERE u.user_id IS NOT NULL
    LOOP
        -- CoinW UIDの復旧
        IF user_record.raw_user_meta_data ? 'coinw_uid' THEN
            coinw_from_meta := user_record.raw_user_meta_data->>'coinw_uid';
            IF coinw_from_meta IS NOT NULL AND coinw_from_meta != '' AND user_record.coinw_uid IS NULL THEN
                UPDATE users 
                SET coinw_uid = coinw_from_meta
                WHERE user_id = user_record.user_id;
                
                RAISE NOTICE 'Updated CoinW UID for user %: %', user_record.user_id, coinw_from_meta;
            END IF;
        END IF;
        
        -- 紹介者情報の復旧
        IF user_record.raw_user_meta_data ? 'referrer_user_id' THEN
            referrer_from_meta := user_record.raw_user_meta_data->>'referrer_user_id';
            IF referrer_from_meta IS NOT NULL AND referrer_from_meta != '' AND user_record.referrer_user_id IS NULL THEN
                UPDATE users 
                SET referrer_user_id = referrer_from_meta
                WHERE user_id = user_record.user_id;
                
                RAISE NOTICE 'Updated referrer for user %: %', user_record.user_id, referrer_from_meta;
            END IF;
        END IF;
    END LOOP;
END $$;

-- 3. 特定の修正: Y9FVT1が紹介リンクから登録された場合のCoinW UID設定
-- (紹介者のCoinW UIDと同じ値を設定する場合)
UPDATE users 
SET coinw_uid = (
    SELECT coinw_uid 
    FROM users 
    WHERE user_id = '2BF53B'
)
WHERE user_id = 'Y9FVT1' 
AND coinw_uid IS NULL
AND (SELECT coinw_uid FROM users WHERE user_id = '2BF53B') IS NOT NULL;

-- 4. 修正結果の確認
SELECT 
    'After Fix - User Data' as check_type,
    user_id,
    email,
    referrer_user_id,
    coinw_uid,
    CASE 
        WHEN referrer_user_id IS NOT NULL THEN '紹介経由'
        ELSE '直接登録'
    END as registration_type,
    created_at
FROM users 
WHERE user_id IN ('Y9FVT1', 'MO08F3', '2BF53B')
ORDER BY created_at DESC;

-- 5. 紹介関係の確認
SELECT 
    'After Fix - Referral Stats' as check_type,
    referrer_user_id as referrer_id,
    (SELECT email FROM users WHERE user_id = referrer_user_id) as referrer_email,
    COUNT(*) as referred_count
FROM users 
WHERE referrer_user_id IS NOT NULL
GROUP BY referrer_user_id
ORDER BY referred_count DESC;

-- 6. CoinW UID設定状況
SELECT 
    'After Fix - CoinW UID Stats' as check_type,
    COUNT(*) as total_users,
    COUNT(coinw_uid) as users_with_coinw_uid,
    COUNT(*) - COUNT(coinw_uid) as users_without_coinw_uid,
    ROUND(COUNT(coinw_uid) * 100.0 / COUNT(*), 2) as coinw_uid_percentage
FROM users;
