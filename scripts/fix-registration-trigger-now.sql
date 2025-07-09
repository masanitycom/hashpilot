-- 登録トリガーの緊急修正

-- 1. 現在のトリガーを削除
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 2. handle_new_user関数を改善（正しい列名を使用）
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    referrer_id TEXT;
    coinw_uid_value TEXT;
    new_user_id TEXT;
BEGIN
    -- ランダムなuser_idを生成
    new_user_id := UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 6));
    
    -- メタデータから値を取得
    referrer_id := NEW.raw_user_meta_data->>'referrer_user_id';
    coinw_uid_value := NEW.raw_user_meta_data->>'coinw_uid';
    
    -- デバッグ情報をログに出力
    RAISE NOTICE 'New user: %, Email: %, CoinW UID: %, Referrer: %', 
                 NEW.id, NEW.email, coinw_uid_value, referrer_id;
    RAISE NOTICE 'Raw metadata: %', NEW.raw_user_meta_data;
    
    -- usersテーブルにレコードを挿入
    INSERT INTO users (
        id,
        user_id, 
        email, 
        referrer_user_id, 
        coinw_uid,
        is_active,
        has_approved_nft,
        total_purchases,
        total_referral_earnings,
        created_at,
        updated_at
    ) VALUES (
        NEW.id,
        new_user_id,
        NEW.email,
        referrer_id,
        coinw_uid_value,
        true,
        false,
        0,
        0,
        NEW.created_at,
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        referrer_user_id = COALESCE(EXCLUDED.referrer_user_id, users.referrer_user_id),
        coinw_uid = COALESCE(EXCLUDED.coinw_uid, users.coinw_uid),
        updated_at = NOW();
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- エラーログを出力
        RAISE WARNING 'handle_new_user error for user %: %', NEW.email, SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. トリガーを再作成
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 4. 確認
SELECT 
    'trigger_recreated' as status,
    t.tgname as trigger_name,
    CASE t.tgenabled 
        WHEN 'O' THEN '✅ 有効'
        ELSE '❌ 無効'
    END as status,
    p.proname as function_name
FROM pg_trigger t
JOIN pg_proc p ON t.tgfoid = p.oid
JOIN pg_class c ON t.tgrelid = c.oid
WHERE t.tgname = 'on_auth_user_created';
