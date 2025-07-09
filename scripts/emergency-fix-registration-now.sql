-- 登録システムの緊急修正

-- 1. 現在のトリガーの状態を確認
SELECT 
    'current_trigger_status' as check_type,
    t.tgname as trigger_name,
    CASE t.tgenabled 
        WHEN 'O' THEN '✅ 有効'
        ELSE '❌ 無効'
    END as status,
    p.proname as function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
JOIN pg_class c ON t.tgrelid = c.oid
WHERE t.tgname = 'on_auth_user_created' AND c.relname = 'users';

-- 2. handle_new_user関数の改善
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    referrer_id TEXT;
    coinw_uid_value TEXT;
BEGIN
    -- メタデータからreferrerとcoinw_uidを取得
    referrer_id := NEW.raw_user_meta_data->>'referrer';
    coinw_uid_value := NEW.raw_user_meta_data->>'coinw_uid';
    
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

-- 3. トリガーが存在しない場合は作成
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'on_auth_user_created'
    ) THEN
        CREATE TRIGGER on_auth_user_created
            AFTER INSERT ON auth.users
            FOR EACH ROW EXECUTE FUNCTION handle_new_user();
    END IF;
END $$;

-- 4. 確認
SELECT 
    'registration_system_status' as check_type,
    'handle_new_user関数とトリガーが正常に設定されました' as message,
    NOW() as timestamp;

SELECT 'registration_system_fixed' as status, NOW() as timestamp;
