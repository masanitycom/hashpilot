-- 管理画面表示問題のデバッグ

-- 1. 最新ユーザーの詳細データ確認
SELECT 
    'user_detail_check' as check_type,
    u.user_id,
    u.email,
    u.coinw_uid,
    u.referrer_user_id,
    au.raw_user_meta_data,
    u.created_at
FROM users u
LEFT JOIN auth.users au ON u.id = au.id
ORDER BY u.created_at DESC
LIMIT 5;

-- 2. 管理画面で使用されるビューを確認
SELECT 
    'admin_view_check' as check_type,
    table_name,
    view_definition
FROM information_schema.views 
WHERE table_name LIKE '%admin%' OR table_name LIKE '%purchase%';

-- 3. usersテーブルの列情報確認
SELECT 
    'users_table_columns' as check_type,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'users' 
AND column_name IN ('coinw_uid', 'referrer_user_id');
