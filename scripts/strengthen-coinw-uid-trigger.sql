-- CoinW UID保存を確実にするトリガーの強化

-- 1. 既存のトリガーを削除
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 2. 強化されたトリガー関数を作成
CREATE OR REPLACE FUNCTION handle_new_user_with_coinw_uid()
RETURNS TRIGGER AS $$
DECLARE
    short_user_id TEXT;
    referrer_id TEXT;
    coinw_uid_value TEXT;
    full_name_value TEXT;
    retry_count INTEGER := 0;
    max_retries INTEGER := 3;
BEGIN
    -- デバッグログ
    RAISE LOG 'New user trigger fired for email: %, metadata: %', NEW.email, NEW.raw_user_meta_data;
    
    -- ショートユーザーIDを生成
    short_user_id := generate_short_user_id();
    
    -- メタデータから値を確実に取得
    referrer_id := NEW.raw_user_meta_data->>'referrer_user_id';
    coinw_uid_value := NEW.raw_user_meta_data->>'coinw_uid';
    full_name_value := NEW.raw_user_meta_data->>'full_name';
    
    -- CoinW UIDの取得をログ出力
    RAISE LOG 'Extracted CoinW UID: % for user: %', coinw_uid_value, NEW.email;
    
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
            
            -- 成功ログ
            RAISE LOG 'Successfully created user: % with CoinW UID: % and referrer: %', 
                short_user_id, coinw_uid_value, referrer_id;
            EXIT;
            
        EXCEPTION
            WHEN unique_violation THEN
                retry_count := retry_count + 1;
                short_user_id := generate_short_user_id();
                RAISE LOG 'Retry % for user creation due to unique violation', retry_count;
                
            WHEN OTHERS THEN
                RAISE LOG 'Error in handle_new_user_with_coinw_uid: %, retrying...', SQLERRM;
                retry_count := retry_count + 1;
        END;
    END LOOP;
    
    -- 最大リトライ回数に達した場合のエラーログ
    IF retry_count >= max_retries THEN
        RAISE LOG 'CRITICAL: Failed to create user after % retries for email: %', max_retries, NEW.email;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. 新しいトリガーを作成
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user_with_coinw_uid();

-- 4. トリガーの動作確認
SELECT 
    'trigger_status' as check_type,
    tgname as trigger_name,
    tgenabled as enabled,
    proname as function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
WHERE tgname = 'on_auth_user_created';
