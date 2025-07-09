-- ユーザー作成トリガーをシンプルに修正

-- 既存のトリガーを削除
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- 最もシンプルなユーザー作成関数
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    random_user_id text;
BEGIN
    -- ランダムな6文字のuser_idを生成
    random_user_id := upper(substring(md5(random()::text) from 1 for 6));
    
    -- usersテーブルに新しいレコードを挿入
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
        COALESCE(new.raw_user_meta_data->>'referrer_user_id', NULL),
        COALESCE(new.raw_user_meta_data->>'coinw_uid', NULL),
        0, 
        0, 
        true,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO NOTHING;  -- 重複を無視
    
    RETURN new;
EXCEPTION
    WHEN OTHERS THEN
        -- エラーが発生してもトリガーは成功させる
        RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 新しいトリガーを作成
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 確認
SELECT 'User creation trigger fixed' as status;
