-- 緊急：新規ユーザー 220B8C のデータ修正

-- 1. まず現在の状況を確認
SELECT 
    'before_fix' as status,
    user_id,
    email,
    coinw_uid,
    referrer_user_id
FROM users 
WHERE user_id = '220B8C' OR email = 'masataka.tak+63@gmail.com';

-- 2. auth.usersからメタデータを取得して手動で設定
DO $$
DECLARE
    auth_user_record RECORD;
    extracted_coinw_uid TEXT;
    extracted_referrer TEXT;
BEGIN
    -- auth.usersからメタデータを取得
    SELECT * INTO auth_user_record
    FROM auth.users 
    WHERE email = 'masataka.tak+63@gmail.com'
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF auth_user_record.id IS NOT NULL THEN
        -- メタデータから値を抽出
        extracted_coinw_uid := auth_user_record.raw_user_meta_data->>'coinw_uid';
        extracted_referrer := auth_user_record.raw_user_meta_data->>'referrer_user_id';
        
        -- usersテーブルを更新
        UPDATE users 
        SET 
            referrer_user_id = COALESCE(extracted_referrer, referrer_user_id),
            coinw_uid = COALESCE(extracted_coinw_uid, coinw_uid),
            updated_at = NOW()
        WHERE email = 'masataka.tak+63@gmail.com';
            
        RAISE NOTICE 'ユーザー % のデータを修正しました。CoinW UID: %, 紹介者: %', 
                     auth_user_record.email, extracted_coinw_uid, extracted_referrer;
    END IF;
END $$;

-- 3. 修正後の確認
SELECT 
    'after_fix' as status,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    created_at
FROM users 
WHERE user_id = '220B8C' OR email = 'masataka.tak+63@gmail.com';

-- 4. 全体の統計を確認
SELECT 
    'final_stats' as check_type,
    COUNT(*) as total_users,
    COUNT(coinw_uid) as users_with_coinw_uid,
    COUNT(referrer_user_id) as users_with_referrer,
    ROUND(COUNT(coinw_uid) * 100.0 / COUNT(*), 2) as coinw_percentage,
    ROUND(COUNT(referrer_user_id) * 100.0 / COUNT(*), 2) as referral_percentage
FROM users;
