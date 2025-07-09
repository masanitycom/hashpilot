-- 登録フォームのデータフローを修正

-- 1. handle_new_user関数を改善
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    referrer_id TEXT;
    coinw_uid_value TEXT;
BEGIN
    -- デバッグ用ログ
    RAISE NOTICE 'handle_new_user triggered for user: %', NEW.email;
    RAISE NOTICE 'raw_user_meta_data: %', NEW.raw_user_meta_data;
    
    -- メタデータからreferrerとcoinw_uidを取得
    referrer_id := NEW.raw_user_meta_data->>'referrer';
    coinw_uid_value := NEW.raw_user_meta_data->>'coinw_uid';
    
    -- デバッグ用ログ
    RAISE NOTICE 'Extracted referrer_id: %, coinw_uid: %', referrer_id, coinw_uid_value;
    
    -- usersテーブルにレコードを挿入または更新
    INSERT INTO users (
        user_id, 
        email, 
        referrer_user_id, 
        coinw_uid,
        is_active,
        created_at,
        updated_at
    ) VALUES (
        NEW.id::TEXT,
        NEW.email,
        referrer_id,
        coinw_uid_value,
        true,
        NOW(),
        NOW()
    )
    ON CONFLICT (user_id) DO UPDATE SET
        email = EXCLUDED.email,
        referrer_user_id = COALESCE(EXCLUDED.referrer_user_id, users.referrer_user_id),
        coinw_uid = COALESCE(EXCLUDED.coinw_uid, users.coinw_uid),
        updated_at = NOW();
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- エラーが発生してもトリガーを停止させない
        RAISE WARNING 'handle_new_user error: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. 確認
SELECT 'registration_trigger_updated' as status, NOW() as timestamp;
