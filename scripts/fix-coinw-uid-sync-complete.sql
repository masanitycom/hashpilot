-- CoinW UID同期の完全修正

-- 1. OOCJ16ユーザーのCoinW UID修正
UPDATE users 
SET coinw_uid = (
    SELECT au.raw_user_meta_data->>'coinw_uid'
    FROM auth.users au 
    WHERE au.id = users.id
    LIMIT 1
),
updated_at = NOW()
WHERE user_id = 'OOCJ16' 
AND coinw_uid IS NULL;

-- 2. 全ユーザーのCoinW UID一括同期
UPDATE users 
SET coinw_uid = subq.auth_coinw_uid,
    updated_at = NOW()
FROM (
    SELECT DISTINCT ON (u.id)
        u.id,
        au.raw_user_meta_data->>'coinw_uid' as auth_coinw_uid
    FROM users u
    JOIN auth.users au ON au.id = u.id
    WHERE u.coinw_uid IS NULL 
    AND au.raw_user_meta_data->>'coinw_uid' IS NOT NULL
    AND au.raw_user_meta_data->>'coinw_uid' != ''
    ORDER BY u.id, au.created_at DESC
) subq
WHERE users.id = subq.id;

-- 3. 新規登録時のトリガー強化
CREATE OR REPLACE FUNCTION handle_new_user_coinw_uid()
RETURNS TRIGGER AS $$
DECLARE
    short_user_id TEXT;
    referrer_id TEXT;
    coinw_uid_value TEXT;
    full_name_value TEXT;
BEGIN
    -- ショートユーザーIDを生成
    short_user_id := generate_short_user_id();
    
    -- メタデータから値を取得
    referrer_id := NEW.raw_user_meta_data->>'referrer_user_id';
    coinw_uid_value := NEW.raw_user_meta_data->>'coinw_uid';
    full_name_value := NEW.raw_user_meta_data->>'full_name';
    
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
        full_name_value,
        referrer_id,
        coinw_uid_value,
        NOW(),
        NOW(),
        true
    );
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG 'Error in handle_new_user_coinw_uid: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. トリガーを再作成
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user_coinw_uid();

-- 5. 結果確認
SELECT 
    'final_coinw_uid_status' as check_type,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    CASE 
        WHEN coinw_uid IS NOT NULL THEN '設定済み'
        ELSE '未設定'
    END as coinw_uid_status
FROM users
ORDER BY created_at DESC;
