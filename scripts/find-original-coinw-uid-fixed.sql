-- V1SPIYユーザーの実際のCoinW UID値を調査（修正版）

-- 1. auth.usersのraw_user_meta_dataから実際の値を取得
SELECT 
    'original_coinw_uid_from_auth' as check_type,
    email,
    raw_user_meta_data,
    raw_user_meta_data->>'coinw_uid' as original_coinw_uid,
    raw_user_meta_data->>'full_name' as full_name,
    created_at
FROM auth.users 
WHERE email = 'masataka.tak+22@gmail.com';

-- 2. 登録時のメタデータ全体を確認
SELECT 
    'full_metadata_check' as check_type,
    email,
    raw_user_meta_data::text as full_metadata,
    created_at
FROM auth.users 
WHERE email = 'masataka.tak+22@gmail.com';

-- 3. 他のユーザーのCoinW UIDパターンを確認（参考用）
SELECT 
    'other_users_coinw_pattern' as check_type,
    email,
    raw_user_meta_data->>'coinw_uid' as coinw_uid,
    LENGTH(raw_user_meta_data->>'coinw_uid') as uid_length,
    created_at
FROM auth.users 
WHERE raw_user_meta_data->>'coinw_uid' IS NOT NULL
ORDER BY created_at;

-- 4. public.usersテーブルの履歴確認
SELECT 
    'users_table_history' as check_type,
    user_id,
    email,
    coinw_uid,
    created_at,
    updated_at
FROM users 
WHERE email = 'masataka.tak+22@gmail.com' OR user_id = 'V1SPIY'
ORDER BY created_at;

-- 5. 登録フォームで使用されるメタデータキーを全て確認
SELECT 
    'all_metadata_keys' as check_type,
    email,
    key as metadata_key,
    value as metadata_value
FROM auth.users, 
     jsonb_each_text(raw_user_meta_data) as kv(key, value)
WHERE email = 'masataka.tak+22@gmail.com';

-- 6. V1SPIYユーザーの完全な情報
SELECT 
    'complete_v1spiy_info' as check_type,
    au.id as auth_id,
    au.email,
    au.created_at as auth_created,
    au.raw_user_meta_data,
    u.user_id,
    u.coinw_uid as current_coinw_uid,
    u.created_at as users_created
FROM auth.users au
LEFT JOIN users u ON au.id = u.id
WHERE au.email = 'masataka.tak+22@gmail.com';
