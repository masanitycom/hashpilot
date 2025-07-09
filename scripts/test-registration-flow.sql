-- 登録フローのテスト

-- 1. 現在のトリガー状況確認
SELECT 
    trigger_name,
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';

-- 2. handle_new_user関数の存在確認
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines 
WHERE routine_name = 'handle_new_user';

-- 3. 現在のユーザー統計
SELECT 
    COUNT(*) as total_users,
    COUNT(coinw_uid) as users_with_coinw,
    COUNT(referrer_user_id) as users_with_referrer,
    ROUND(COUNT(coinw_uid) * 100.0 / COUNT(*), 2) as coinw_percentage,
    ROUND(COUNT(referrer_user_id) * 100.0 / COUNT(*), 2) as referrer_percentage
FROM users;

-- 4. 最新5人のユーザー確認
SELECT 
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    created_at
FROM users 
ORDER BY created_at DESC 
LIMIT 5;
