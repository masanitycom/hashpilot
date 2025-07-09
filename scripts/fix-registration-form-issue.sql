-- 登録フォームの問題を修正するためのデータベース側の対応

-- 1. 登録時のメタデータ保存を確実にするトリガーの再作成
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE OR REPLACE FUNCTION handle_new_user_registration()
RETURNS TRIGGER AS $$
DECLARE
    short_user_id TEXT;
    referrer_id TEXT;
    coinw_uid_value TEXT;
    full_name_value TEXT;
    retry_count INTEGER := 0;
    max_retries INTEGER := 3;
BEGIN
    -- 詳細なデバッグログ
    RAISE LOG 'Registration trigger fired for: %', NEW.email;
    RAISE LOG 'Full metadata received: %', NEW.raw_user_meta_data;
    
    -- ショートユーザーIDを生成
    short_user_id := generate_short_user_id();
    
    -- メタデータから値を取得（複数の方法で試行）
    referrer_id := COALESCE(
        NEW.raw_user_meta_data->>'referrer_user_id',
        NEW.raw_user_meta_data->>'ref',
        NEW.user_metadata->>'referrer_user_id'
    );
    
    coinw_uid_value := COALESCE(
        NEW.raw_user_meta_data->>'coinw_uid',
        NEW.raw_user_meta_data->>'coinw',
        NEW.user_metadata->>'coinw_uid'
    );
    
    full_name_value := COALESCE(
        NEW.raw_user_meta_data->>'full_name',
        NEW.user_metadata->>'full_name'
    );
    
    -- 取得した値をログ出力
    RAISE LOG 'Extracted values - referrer: %, coinw_uid: %, full_name: %', 
        referrer_id, coinw_uid_value, full_name_value;
    
    -- リトライ機能付きでusersテーブルに挿入
    WHILE retry_count < max_retries LOOP
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
                short_user_id,
                NEW.email,
                full_name_value,
                referrer_id,
                coinw_uid_value,
                NOW(),
                NOW(),
                true,
                false,
                0,
                0
            );
            
            RAISE LOG 'Successfully created user: % with coinw_uid: % and referrer: %', 
                short_user_id, coinw_uid_value, referrer_id;
            EXIT;
            
        EXCEPTION
            WHEN unique_violation THEN
                retry_count := retry_count + 1;
                short_user_id := generate_short_user_id();
                RAISE LOG 'Retry % due to unique violation', retry_count;
                
            WHEN OTHERS THEN
                RAISE LOG 'Error in user creation: %, retrying...', SQLERRM;
                retry_count := retry_count + 1;
        END;
    END LOOP;
    
    IF retry_count >= max_retries THEN
        RAISE LOG 'CRITICAL: Failed to create user after % retries for: %', max_retries, NEW.email;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 新しいトリガーを作成
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user_registration();

-- トリガーの確認
SELECT 
    'trigger_check' as status,
    tgname as trigger_name,
    tgenabled as enabled,
    proname as function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgname = 'on_auth_user_created';
