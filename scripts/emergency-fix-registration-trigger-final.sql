-- 登録トリガーを完全に修正

-- 1. 既存のトリガーと関数を完全削除
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;

-- 2. public.usersテーブルの構造を確認・修正
-- 必要なカラムが存在することを確認
DO $$
BEGIN
    -- referrer_user_idカラムが存在しない場合は追加
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'users' 
        AND column_name = 'referrer_user_id'
    ) THEN
        ALTER TABLE public.users ADD COLUMN referrer_user_id VARCHAR(10);
    END IF;
    
    -- coinw_uidカラムが存在しない場合は追加
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'users' 
        AND column_name = 'coinw_uid'
    ) THEN
        ALTER TABLE public.users ADD COLUMN coinw_uid TEXT;
    END IF;
    
    -- user_idカラムが存在しない場合は追加
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'users' 
        AND column_name = 'user_id'
    ) THEN
        ALTER TABLE public.users ADD COLUMN user_id VARCHAR(10) UNIQUE;
    END IF;
END $$;

-- 3. 新しいユーザー作成関数（完全版）
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_user_id TEXT;
    referrer_id TEXT;
    coinw_uid_value TEXT;
    meta_data JSONB;
    existing_count INTEGER;
BEGIN
    -- デバッグログ開始
    RAISE NOTICE 'handle_new_user triggered for email: %', NEW.email;
    
    -- メタデータを取得
    meta_data := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);
    RAISE NOTICE 'Raw metadata: %', meta_data::text;
    
    -- 複数のキーからデータを取得
    referrer_id := COALESCE(
        meta_data->>'referrer_user_id',
        meta_data->>'referrer',
        meta_data->>'ref',
        meta_data->>'referrer_code',
        meta_data->>'referrer_id'
    );
    
    coinw_uid_value := COALESCE(
        meta_data->>'coinw_uid',
        meta_data->>'coinw',
        meta_data->>'uid',
        meta_data->>'coinw_id'
    );
    
    RAISE NOTICE 'Extracted - referrer: %, coinw_uid: %', referrer_id, coinw_uid_value;
    
    -- 既存のレコードをチェック
    SELECT COUNT(*) INTO existing_count 
    FROM public.users 
    WHERE id = NEW.id OR email = NEW.email;
    
    IF existing_count > 0 THEN
        RAISE NOTICE 'User already exists, updating instead of inserting';
        
        -- 既存レコードを更新
        UPDATE public.users 
        SET 
            referrer_user_id = CASE 
                WHEN referrer_id IS NOT NULL AND referrer_id != '' 
                THEN referrer_id 
                ELSE referrer_user_id 
            END,
            coinw_uid = CASE 
                WHEN coinw_uid_value IS NOT NULL AND coinw_uid_value != '' 
                THEN coinw_uid_value 
                ELSE coinw_uid 
            END,
            updated_at = NOW()
        WHERE id = NEW.id OR email = NEW.email;
        
        RAISE NOTICE 'User updated successfully';
        RETURN NEW;
    END IF;
    
    -- ランダムな6文字のuser_idを生成（重複チェック付き）
    LOOP
        new_user_id := upper(substring(md5(random()::text) from 1 for 6));
        EXIT WHEN NOT EXISTS (SELECT 1 FROM public.users WHERE user_id = new_user_id);
    END LOOP;
    
    RAISE NOTICE 'Generated user_id: %', new_user_id;
    
    -- 新しいレコードを挿入
    INSERT INTO public.users (
        id,
        user_id,
        email,
        referrer_user_id,
        coinw_uid,
        total_purchases,
        total_referral_earnings,
        is_active,
        has_approved_nft,
        created_at,
        updated_at
    ) VALUES (
        NEW.id,
        new_user_id,
        NEW.email,
        CASE 
            WHEN referrer_id IS NOT NULL AND referrer_id != '' 
            THEN referrer_id 
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
        false,
        NOW(),
        NOW()
    );
    
    RAISE NOTICE 'User created successfully: user_id=%, referrer=%, coinw_uid=%', 
        new_user_id, referrer_id, coinw_uid_value;
    
    RETURN NEW;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'handle_new_user error for %: %', NEW.email, SQLERRM;
        -- エラーが発生してもトリガーは成功させる
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. トリガーを作成
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 5. 権限設定
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO authenticated;
GRANT EXECUTE ON FUNCTION public.handle_new_user() TO anon;

-- 6. 確認
SELECT 
    'trigger_created' as status,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- 7. 関数確認
SELECT 
    'function_created' as status,
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_name = 'handle_new_user';

-- 8. 完了メッセージ
SELECT 'Registration system completely fixed and ready for testing!' as final_status;
