-- 登録システムのデバッグテスト

-- 1. 現在のトリガー状況
SELECT 
    'trigger_status' as check_type,
    trigger_name,
    event_object_table,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- 2. 関数の存在確認
SELECT 
    'function_status' as check_type,
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_name = 'handle_new_user';

-- 3. 最新ユーザーのメタデータ確認
SELECT 
    'latest_user_metadata' as check_type,
    email,
    raw_user_meta_data,
    created_at
FROM auth.users 
ORDER BY created_at DESC 
LIMIT 3;

-- 4. usersテーブルの最新データ
SELECT 
    'latest_users_table' as check_type,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    created_at
FROM users 
ORDER BY created_at DESC 
LIMIT 3;
