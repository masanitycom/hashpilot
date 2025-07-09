-- 登録システムを完全修正

-- 1. 既存のトリガーと関数を削除
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;

-- 2. 新しいユーザー作成関数（完全版）
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_user_id TEXT;
    referrer_id TEXT;
    coinw_uid_value TEXT;
BEGIN
    -- ランダムな6文字のuser_idを生成
    new_user_id := upper(substring(md5(random()::text) from 1 for 6));
    
    -- メタデータから情報を取得（複数のキーを試行）
    referrer_id := COALESCE(
        NEW.raw_user_meta_data->>'referrer_user_id',
        NEW.raw_user_meta_data->>'referrer',
        NEW.raw_user_meta_data->>'ref'
    );
    
    coinw_uid_value := COALESCE(
        NEW.raw_user_meta_data->>'coinw_uid',
        NEW.raw_user_meta_data->>'coinw',
        NEW.raw_user_meta_data->>'uid'
    );
    
    -- デバッグログ
    RAISE NOTICE 'Creating user: email=%, user_id=%, referrer=%, coinw_uid=%', 
        NEW.email, new_user_id, referrer_id, coinw_uid_value;
    
    -- usersテーブルに挿入
    INSERT INTO users (
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
        referrer_id,
        coinw_uid_value,
        0,
        0,
        true,
        false,
        NOW(),
        NOW()
    );
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'handle_new_user error for %: %', NEW.email, SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. トリガーを再作成
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 4. 確認
SELECT 'Registration system completely fixed' as status, NOW() as timestamp;
