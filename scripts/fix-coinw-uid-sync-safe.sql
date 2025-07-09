-- CoinW UID同期の安全な修正

-- 1. 問題のあるユーザーを特定
SELECT 
    u.user_id,
    u.email,
    u.coinw_uid as current_coinw_uid,
    COUNT(au.id) as auth_records_count
FROM users u
LEFT JOIN auth.users au ON au.id = u.id
WHERE u.coinw_uid IS NULL
GROUP BY u.user_id, u.email, u.coinw_uid
HAVING COUNT(au.id) > 1;

-- 2. 安全な方法でCoinW UIDを同期（一意性を保証）
UPDATE users 
SET coinw_uid = subq.coinw_uid_value
FROM (
    SELECT DISTINCT ON (u.id)
        u.id,
        au.raw_user_meta_data->>'coinw_uid' as coinw_uid_value
    FROM users u
    JOIN auth.users au ON au.id = u.id
    WHERE u.coinw_uid IS NULL 
    AND au.raw_user_meta_data->>'coinw_uid' IS NOT NULL
    ORDER BY u.id, au.created_at DESC
) subq
WHERE users.id = subq.id;

-- 3. 特定ユーザーの手動修正（V1SPIYユーザー）
DO $$
DECLARE
    target_user_id TEXT;
    auth_coinw_uid TEXT;
BEGIN
    -- V1SPIYユーザーのIDを取得
    SELECT id INTO target_user_id
    FROM users 
    WHERE user_id = 'V1SPIY' OR email = 'masataka.tak+22@gmail.com'
    LIMIT 1;
    
    IF target_user_id IS NOT NULL THEN
        -- auth.usersからCoinW UIDを取得（最新のレコード）
        SELECT raw_user_meta_data->>'coinw_uid' INTO auth_coinw_uid
        FROM auth.users 
        WHERE id = target_user_id
        AND raw_user_meta_data->>'coinw_uid' IS NOT NULL
        ORDER BY created_at DESC
        LIMIT 1;
        
        -- usersテーブルを更新
        IF auth_coinw_uid IS NOT NULL THEN
            UPDATE users 
            SET coinw_uid = auth_coinw_uid,
                updated_at = NOW()
            WHERE id = target_user_id;
            
            RAISE NOTICE 'Updated CoinW UID for V1SPIY: %', auth_coinw_uid;
        ELSE
            RAISE NOTICE 'No CoinW UID found in auth.users for V1SPIY';
        END IF;
    ELSE
        RAISE NOTICE 'V1SPIY user not found';
    END IF;
END $$;

-- 4. 結果確認
SELECT 
    user_id,
    email,
    coinw_uid,
    CASE 
        WHEN coinw_uid IS NOT NULL THEN 'あり'
        ELSE 'なし'
    END as coinw_uid_status
FROM users
ORDER BY created_at DESC;

-- 5. admin_purchases_viewの動作確認
SELECT 
    user_id,
    email,
    coinw_uid,
    amount_usd,
    payment_status
FROM admin_purchases_view
WHERE email = 'masataka.tak+22@gmail.com'
LIMIT 5;
