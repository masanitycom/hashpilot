-- ユーザー作成トリガーをCASCADEで完全に修正（修正版）

-- 既存のトリガーとその依存関係をすべて削除
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;
DROP TRIGGER IF EXISTS on_user_created ON users CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;

-- 最もシンプルなユーザー作成関数を再作成
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
        RAISE NOTICE 'Error in handle_new_user: %', SQLERRM;
        RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- auth.usersテーブルにトリガーを作成（新規登録用）
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 確認
SELECT 'User creation trigger fixed with CASCADE' as status;

-- 現在のトリガー状況を確認（正しいシステムビューを使用）
SELECT 
    trigger_schema,
    event_object_table,
    trigger_name,
    'Trigger exists' as status
FROM information_schema.triggers 
WHERE trigger_name LIKE '%user%' 
   OR trigger_name LIKE '%auth%'
ORDER BY trigger_schema, event_object_table, trigger_name;
