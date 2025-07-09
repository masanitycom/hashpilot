-- CoinW UIDシステムの最終調整

-- 1. テスト用のCoinW UIDを実際の値に更新（必要に応じて）
-- UPDATE users 
-- SET coinw_uid = '実際のCoinW_UID'
-- WHERE user_id = 'V1SPIY';

-- 2. 新規登録時のCoinW UID同期を確実にするトリガー強化
CREATE OR REPLACE FUNCTION handle_new_user_with_metadata()
RETURNS TRIGGER AS $$
DECLARE
    short_user_id TEXT;
    referrer_id TEXT;
    coinw_uid_value TEXT;
BEGIN
    -- ショートユーザーIDを生成
    short_user_id := generate_short_user_id();
    
    -- メタデータからreferrer_user_idとcoinw_uidを取得
    referrer_id := NEW.raw_user_meta_data->>'referrer_user_id';
    coinw_uid_value := NEW.raw_user_meta_data->>'coinw_uid';
    
    -- デバッグログ
    RAISE LOG 'Creating user with CoinW UID: % for email: %', coinw_uid_value, NEW.email;
    
    -- usersテーブルにレコードを挿入
    INSERT INTO public.users (
        id,
        user_id,
        email,
        full_name,
        referrer_user_id,
        coinw_uid,
        created_at,
        updated_at,
        is_active
    ) VALUES (
        NEW.id,
        short_user_id,
        NEW.email,
        NEW.raw_user_meta_data->>'full_name',
        referrer_id,
        coinw_uid_value,
        NOW(),
        NOW(),
        true
    );
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG 'Error in handle_new_user_with_metadata: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. 既存の他のユーザーのCoinW UIDも同期（安全に）
UPDATE users 
SET coinw_uid = (
    SELECT raw_user_meta_data->>'coinw_uid' 
    FROM auth.users 
    WHERE auth.users.id = users.id
    LIMIT 1
),
updated_at = NOW()
WHERE coinw_uid IS NULL 
AND EXISTS (
    SELECT 1 FROM auth.users 
    WHERE auth.users.id = users.id 
    AND raw_user_meta_data->>'coinw_uid' IS NOT NULL
    AND raw_user_meta_data->>'coinw_uid' != ''
);

-- 4. 最終確認
SELECT 
    'final_coinw_uid_status' as check_type,
    COUNT(*) as total_users,
    COUNT(coinw_uid) as users_with_coinw_uid,
    COUNT(*) - COUNT(coinw_uid) as users_without_coinw_uid
FROM users;

-- 5. 管理画面での表示確認
SELECT 
    'admin_view_final_check' as check_type,
    user_id,
    email,
    coinw_uid,
    amount_usd
FROM admin_purchases_view 
WHERE coinw_uid IS NOT NULL
ORDER BY created_at DESC;
