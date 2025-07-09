-- 紹介システムの緊急修正（構文エラー修正版）

-- 1. 現在の紹介者データを確認
SELECT 
    u.user_id,
    u.email,
    u.referrer_user_id,
    CASE 
        WHEN u.referrer_user_id IS NULL THEN '直接登録'
        ELSE CONCAT('紹介者: ', u.referrer_user_id)
    END as referral_status,
    u.created_at
FROM users u 
ORDER BY u.created_at DESC 
LIMIT 10;

-- 2. auth.usersのraw_user_meta_dataを確認
SELECT 
    au.id,
    au.email,
    au.raw_user_meta_data,
    au.created_at
FROM auth.users au 
ORDER BY au.created_at DESC 
LIMIT 10;

-- 3. 紹介者情報を修正するための関数を作成（修正版）
CREATE OR REPLACE FUNCTION fix_referral_data()
RETURNS void AS $$
DECLARE
    user_record RECORD;
    referrer_code text;
    coinw_uid_value text;
BEGIN
    -- auth.usersからメタデータを取得してusersテーブルを更新
    FOR user_record IN 
        SELECT 
            au.id,
            au.email,
            au.raw_user_meta_data,
            u.user_id
        FROM auth.users au
        LEFT JOIN users u ON au.id = u.id
        WHERE au.raw_user_meta_data IS NOT NULL
    LOOP
        -- referrer_user_idを取得（修正：user_recordを使用）
        referrer_code := user_record.raw_user_meta_data->>'referrer_user_id';
        coinw_uid_value := user_record.raw_user_meta_data->>'coinw_uid';
        
        -- usersテーブルを更新
        UPDATE users 
        SET 
            referrer_user_id = CASE 
                WHEN referrer_code IS NOT NULL AND referrer_code != '' 
                THEN referrer_code 
                ELSE referrer_user_id 
            END,
            coinw_uid = CASE 
                WHEN coinw_uid_value IS NOT NULL AND coinw_uid_value != '' 
                THEN coinw_uid_value 
                ELSE coinw_uid 
            END,
            updated_at = NOW()
        WHERE id = user_record.id;
        
        RAISE NOTICE 'Updated user %: referrer=%, coinw_uid=%', 
            user_record.email, referrer_code, coinw_uid_value;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 4. 修正関数を実行
SELECT fix_referral_data();

-- 5. 修正後の状態を確認
SELECT 
    u.user_id,
    u.email,
    u.referrer_user_id,
    u.coinw_uid,
    CASE 
        WHEN u.referrer_user_id IS NULL OR u.referrer_user_id = '' THEN '直接登録'
        ELSE CONCAT('紹介者: ', u.referrer_user_id)
    END as referral_status,
    u.created_at
FROM users u 
ORDER BY u.created_at DESC 
LIMIT 10;

-- 6. 紹介関係の詳細確認
SELECT 
    u1.user_id as referrer_id,
    u1.email as referrer_email,
    COUNT(u2.id) as referred_count
FROM users u1
LEFT JOIN users u2 ON u1.user_id = u2.referrer_user_id
GROUP BY u1.user_id, u1.email
HAVING COUNT(u2.id) > 0
ORDER BY referred_count DESC;
