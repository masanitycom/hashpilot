-- 正しいメールアドレスでユーザー情報を変更
-- 対象: tmtm1108tmtm@gmail.com -> yutaka19791105@gmail.com

-- まず現在のユーザー情報を確認
SELECT 
    au.id as auth_id,
    au.email as auth_email,
    u.user_id,
    u.email as user_email,
    u.coinw_uid
FROM auth.users au
LEFT JOIN users u ON au.id = u.id
WHERE au.email = 'tmtm1108tmtm@gmail.com';

-- auth.usersテーブルのメールアドレスを更新
UPDATE auth.users 
SET 
    email = 'yutaka19791105@gmail.com',
    raw_user_meta_data = jsonb_set(
        COALESCE(raw_user_meta_data, '{}'),
        '{email}',
        '"yutaka19791105@gmail.com"'
    ),
    email_confirmed_at = NOW(),
    updated_at = NOW()
WHERE email = 'tmtm1108tmtm@gmail.com';

-- usersテーブルのメールアドレスを更新
UPDATE users 
SET 
    email = 'yutaka19791105@gmail.com',
    updated_at = NOW()
WHERE email = 'tmtm1108tmtm@gmail.com';

-- パスワードリセットトークンを生成（実際のパスワード変更はSupabase管理画面で行うことを推奨）
-- または一時的なパスワードハッシュを設定
UPDATE auth.users 
SET 
    encrypted_password = crypt('Ko20250101@', gen_salt('bf')),
    updated_at = NOW()
WHERE email = 'yutaka19791105@gmail.com';

-- 変更後の確認
SELECT 'Updated user information:' as info;
SELECT 
    au.id as auth_id,
    au.email as auth_email,
    u.user_id,
    u.email as user_email,
    u.coinw_uid,
    au.email_confirmed_at
FROM auth.users au
LEFT JOIN users u ON au.id = u.id
WHERE au.email = 'yutaka19791105@gmail.com';
