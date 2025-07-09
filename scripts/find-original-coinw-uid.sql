-- V1SPIYユーザーの実際のCoinW UID値を調査

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
    user_metadata::text as user_metadata_field,
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

-- 4. public.usersテーブルの履歴確認（更新前の値があるかも）
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
    jsonb_object_keys(raw_user_meta_data) as metadata_keys,
    raw_user_meta_data->>jsonb_object_keys(raw_user_meta_data) as metadata_values
FROM auth.users 
WHERE email = 'masataka.tak+22@gmail.com';
