-- CoinW UID完全自動反映システム

-- 1. OOCJ16の即座修正
UPDATE users 
SET coinw_uid = '3722480',
    updated_at = NOW()
WHERE user_id = 'OOCJ16';

-- 2. 全ユーザーの一括同期
UPDATE users 
SET coinw_uid = auth_data.coinw_uid,
    updated_at = NOW()
FROM (
    SELECT DISTINCT ON (u.id)
        u.id,
        au.raw_user_meta_data->>'coinw_uid' as coinw_uid
    FROM users u
    JOIN auth.users au ON au.id = u.id
    WHERE au.raw_user_meta_data->>'coinw_uid' IS NOT NULL
    AND au.raw_user_meta_data->>'coinw_uid' != ''
    ORDER BY u.id
) auth_data
WHERE users.id = auth_data.id
AND (users.coinw_uid IS NULL OR users.coinw_uid != auth_data.coinw_uid);

-- 3. 強化されたトリガー関数
CREATE OR REPLACE FUNCTION handle_new_user_complete()
RETURNS TRIGGER AS $$
DECLARE
    short_user_id TEXT;
    referrer_id TEXT;
    coinw_uid_value TEXT;
    full_name_value TEXT;
    retry_count INTEGER := 0;
    max_retries INTEGER := 3;
BEGIN
    -- ショートユーザーIDを生成
    short_user_id := generate_short_user_id();
    
    -- メタデータから値を確実に取得
    referrer_id := COALESCE(NEW.raw_user_meta_data->>'referrer_user_id', NULL);
    coinw_uid_value := COALESCE(NEW.raw_user_meta_data->>'coinw_uid', NULL);
    full_name_value := COALESCE(NEW.raw_user_meta_data->>'full_name', NULL);
    
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
            
            -- 成功したらログ出力してループを抜ける
            RAISE LOG 'Successfully created user: % with CoinW UID: %', short_user_id, coinw_uid_value;
            EXIT;
            
        EXCEPTION
            WHEN unique_violation THEN
                retry_count := retry_count + 1;
                short_user_id := generate_short_user_id();
                RAISE LOG 'Retry % for user creation due to unique violation', retry_count;
                
            WHEN OTHERS THEN
                RAISE LOG 'Error in handle_new_user_complete: %, retrying...', SQLERRM;
                retry_count := retry_count + 1;
        END;
    END LOOP;
    
    -- 最大リトライ回数に達した場合のエラーログ
    IF retry_count >= max_retries THEN
        RAISE LOG 'Failed to create user after % retries for email: %', max_retries, NEW.email;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. CoinW UID同期専用関数
CREATE OR REPLACE FUNCTION sync_coinw_uid_from_auth()
RETURNS INTEGER AS $$
DECLARE
    sync_count INTEGER := 0;
    user_record RECORD;
BEGIN
    -- auth.usersからCoinW UIDを取得してusersテーブルを更新
    FOR user_record IN 
        SELECT 
            u.id,
            u.user_id,
            au.raw_user_meta_data->>'coinw_uid' as auth_coinw_uid
        FROM users u
        JOIN auth.users au ON au.id = u.id
        WHERE au.raw_user_meta_data->>'coinw_uid' IS NOT NULL
        AND au.raw_user_meta_data->>'coinw_uid' != ''
        AND (u.coinw_uid IS NULL OR u.coinw_uid != au.raw_user_meta_data->>'coinw_uid')
    LOOP
        UPDATE users 
        SET coinw_uid = user_record.auth_coinw_uid,
            updated_at = NOW()
        WHERE id = user_record.id;
        
        sync_count := sync_count + 1;
        RAISE LOG 'Synced CoinW UID for user %: %', user_record.user_id, user_record.auth_coinw_uid;
    END LOOP;
    
    RETURN sync_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. トリガーを完全に再作成
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user_complete();

-- 6. 定期同期のためのスケジュール関数（手動実行用）
CREATE OR REPLACE FUNCTION manual_coinw_uid_sync()
RETURNS TEXT AS $$
DECLARE
    result_count INTEGER;
BEGIN
    SELECT sync_coinw_uid_from_auth() INTO result_count;
    RETURN format('CoinW UID同期完了: %s件のレコードを更新しました', result_count);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. 即座に同期実行
SELECT sync_coinw_uid_from_auth() as synced_records;

-- 8. 最終確認
SELECT 
    'final_verification' as check_type,
    user_id,
    email,
    coinw_uid,
    CASE 
        WHEN coinw_uid IS NOT NULL THEN '✅ 設定済み'
        ELSE '❌ 未設定'
    END as status,
    created_at
FROM users
WHERE user_id IN ('OOCJ16', 'V1SPIY', '2BF53B', '7A9637', 'Y9FVT1', 'MO08F3')
ORDER BY created_at DESC;
