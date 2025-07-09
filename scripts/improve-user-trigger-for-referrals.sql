-- ユーザー作成トリガーを改善（紹介システム対応）

-- 既存のトリガーを削除
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- 改善されたユーザー作成関数
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    random_user_id text;
    referrer_code text;
    coinw_uid_value text;
BEGIN
    -- ランダムな6文字のuser_idを生成
    random_user_id := upper(substring(md5(random()::text) from 1 for 6));
    
    -- メタデータから紹介者情報を取得
    referrer_code := COALESCE(new.raw_user_meta_data->>'referrer_user_id', '');
    coinw_uid_value := COALESCE(new.raw_user_meta_data->>'coinw_uid', '');
    
    -- デバッグログ
    RAISE NOTICE 'Creating user: email=%, referrer=%, coinw_uid=%', 
        new.email, referrer_code, coinw_uid_value;
    
    -- usersテーブルに新しいレコードを挿入
    INSERT INTO public.users (
        id, 
        user_id, 
        email, 
        referrer_user_id,
        coinw_uid,
        total_purchases, 
        total_referral_earnings, 
        is_active
    )
    VALUES (
        new.id, 
        random_user_id, 
        new.email, 
        CASE 
            WHEN referrer_code IS NOT NULL AND referrer_code != '' 
            THEN referrer_code 
            ELSE NULL 
        END,
        CASE 
            WHEN coinw_uid_value IS NOT NULL AND coinw_uid_value != '' 
            THEN coinw_uid_value 
            ELSE NULL 
        END,
        0, 
        0, 
        true
    );
    
    RAISE NOTICE 'User created successfully: %', random_user_id;
    
    RETURN new;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error creating user: %', SQLERRM;
        RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 新しいトリガーを作成
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- トリガーの状態を確認
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';
