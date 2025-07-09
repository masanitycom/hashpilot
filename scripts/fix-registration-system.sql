-- 登録システムの修正

-- 1. 現在のトリガーを確認（修正版）
SELECT 
    'current_trigger_check' as check_type,
    t.tgname,
    t.tgenabled,
    t.tgtype,
    p.proname as function_name,
    c.relname as table_name,
    n.nspname as schema_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE t.tgname = 'on_auth_user_created';

-- 2. 既存のトリガーと関数を削除
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- 3. 改良版トリガー関数の作成
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    new_user_id text;
    referrer_id text;
    coinw_uid_value text;
    full_name_value text;
    registration_source text;
BEGIN
    -- ランダムなユーザーIDを生成（重複チェック付き）
    LOOP
        new_user_id := upper(substring(md5(random()::text) from 1 for 6));
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.users WHERE user_id = new_user_id);
    END LOOP;
    
    -- メタデータから値を取得（NULLチェック付き）
    IF NEW.raw_user_meta_data IS NOT NULL THEN
        referrer_id := NEW.raw_user_meta_data->>'referrer_user_id';
        coinw_uid_value := NEW.raw_user_meta_data->>'coinw_uid';
        full_name_value := NEW.raw_user_meta_data->>'full_name';
        registration_source := NEW.raw_user_meta_data->>'registration_source';
    END IF;
    
    -- デバッグログ（詳細）
    RAISE LOG 'New user registration: email=%, user_id=%, referrer=%, coinw_uid=%, metadata=%', 
        NEW.email, new_user_id, referrer_id, coinw_uid_value, NEW.raw_user_meta_data;
    
    -- usersテーブルに挿入（エラーハンドリング付き）
    BEGIN
        INSERT INTO public.users (
            id,
            user_id,
            email,
            full_name,
            referrer_user_id,
            coinw_uid,
            created_at,
            updated_at,
            is_active,
            has_approved_nft,
            total_purchases,
            total_referral_earnings
        ) VALUES (
            NEW.id,
            new_user_id,
            NEW.email,
            COALESCE(full_name_value, ''),
            referrer_id,
            coinw_uid_value,
            NOW(),
            NOW(),
            true,
            false,
            0,
            0
        );
        
        RAISE LOG 'User successfully created: user_id=%, email=%', new_user_id, NEW.email;
        
    EXCEPTION
        WHEN unique_violation THEN
            RAISE LOG 'Unique violation for user: %, retrying with new ID', NEW.email;
            -- 新しいIDで再試行
            new_user_id := upper(substring(md5(random()::text || NEW.email) from 1 for 6));
            INSERT INTO public.users (
                id, user_id, email, full_name, referrer_user_id, coinw_uid,
                created_at, updated_at, is_active, has_approved_nft,
                total_purchases, total_referral_earnings
            ) VALUES (
                NEW.id, new_user_id, NEW.email, COALESCE(full_name_value, ''),
                referrer_id, coinw_uid_value, NOW(), NOW(), true, false, 0, 0
            );
        WHEN OTHERS THEN
            RAISE LOG 'Error inserting user: %, error: %', NEW.email, SQLERRM;
            RAISE;
    END;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE LOG 'Critical error in handle_new_user for %: %', NEW.email, SQLERRM;
        -- エラーが発生してもトリガーは成功させる（認証は通す）
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. トリガーの作成
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 5. 権限設定
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO anon;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO service_role;

-- 6. テスト用の確認
SELECT 
    'trigger_recreation_complete' as status,
    'Improved trigger and function created with better error handling' as message,
    NOW() as timestamp;

-- 7. 関数の詳細確認
SELECT 
    'function_details' as check_type,
    proname as function_name,
    pronargs as arg_count,
    prorettype::regtype as return_type,
    prosecdef as security_definer,
    proacl as permissions
FROM pg_proc 
WHERE proname = 'handle_new_user';

-- 8. トリガーの詳細確認
SELECT 
    'trigger_details' as check_type,
    t.tgname as trigger_name,
    t.tgenabled as enabled,
    c.relname as table_name,
    p.proname as function_name,
    CASE t.tgtype & 2 
        WHEN 0 THEN 'BEFORE'
        ELSE 'AFTER'
    END as timing,
    CASE t.tgtype & 4
        WHEN 0 THEN 'ROW'
        ELSE 'STATEMENT'
    END as level
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE t.tgname = 'on_auth_user_created';
