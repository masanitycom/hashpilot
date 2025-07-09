-- 紹介リンクのデータフローを修正

-- 1. 現在の登録フォームの問題を確認
SELECT 'Checking current registration system' as status;

-- 2. pre-registerページからregisterページへのデータ受け渡しを修正
-- この問題はフロントエンドの問題の可能性が高い

-- 3. 登録時のメタデータ取得を強化
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    new_user_id TEXT;
    referrer_id TEXT;
    coinw_uid_value TEXT;
    meta_data JSONB;
BEGIN
    -- ランダムな6文字のuser_idを生成
    new_user_id := upper(substring(md5(random()::text) from 1 for 6));
    
    -- メタデータを取得
    meta_data := COALESCE(NEW.raw_user_meta_data, '{}'::jsonb);
    
    -- 複数のキーからデータを取得
    referrer_id := COALESCE(
        meta_data->>'referrer_user_id',
        meta_data->>'referrer',
        meta_data->>'ref',
        meta_data->>'referrer_code'
    );
    
    coinw_uid_value := COALESCE(
        meta_data->>'coinw_uid',
        meta_data->>'coinw',
        meta_data->>'uid',
        meta_data->>'coinw_id'
    );
    
    -- デバッグログを詳細化
    RAISE NOTICE 'User creation debug: email=%, user_id=%, referrer=%, coinw_uid=%, full_metadata=%', 
        NEW.email, new_user_id, referrer_id, coinw_uid_value, meta_data::text;
    
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
        RAISE WARNING 'handle_new_user error for %: %, metadata was: %', NEW.email, SQLERRM, meta_data::text;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

SELECT 'Registration function updated with enhanced debugging' as status, NOW() as timestamp;
