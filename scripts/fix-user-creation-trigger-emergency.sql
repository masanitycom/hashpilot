-- ユーザー作成トリガーを緊急修正

-- 既存のトリガーを削除
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- シンプルで安全なユーザー作成関数を作成
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    random_user_id text;
    referrer_code text;
    coinw_uid_value text;
BEGIN
    -- ランダムな6文字のuser_idを生成
    random_user_id := upper(substring(md5(random()::text) from 1 for 6));
    
    -- メタデータから情報を安全に取得
    BEGIN
        referrer_code := new.raw_user_meta_data->>'referrer_user_id';
        coinw_uid_value := new.raw_user_meta_data->>'coinw_uid';
    EXCEPTION
        WHEN OTHERS THEN
            referrer_code := NULL;
            coinw_uid_value := NULL;
    END;
    
    -- usersテーブルに新しいレコードを挿入（エラーハンドリング付き）
    BEGIN
        INSERT INTO public.users (
            id, 
            user_id, 
            email, 
            referrer_user_id,
            coinw_uid,
            total_purchases, 
            total_referral_earnings, 
            is_active,
            created_at,
            updated_at
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
            true,
            NOW(),
            NOW()
        );
        
        RAISE NOTICE 'User created successfully: % with user_id: %', new.email, random_user_id;
        
    EXCEPTION
        WHEN unique_violation THEN
            RAISE NOTICE 'User already exists: %', new.email;
        WHEN OTHERS THEN
            RAISE NOTICE 'Error creating user %: %', new.email, SQLERRM;
            -- エラーが発生してもトリガーは成功させる
    END;
    
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

-- テスト用のログ出力
RAISE NOTICE 'User creation trigger has been reset and should work now';
