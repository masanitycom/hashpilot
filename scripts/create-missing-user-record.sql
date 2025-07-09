-- masataka.tak@gmail.com のユーザーレコードを手動作成
DO $$
DECLARE
    auth_user_id uuid;
    random_user_id text;
BEGIN
    -- auth.usersからIDを取得
    SELECT id INTO auth_user_id 
    FROM auth.users 
    WHERE email = 'masataka.tak@gmail.com';
    
    IF auth_user_id IS NULL THEN
        RAISE EXCEPTION 'ユーザーが見つかりません: masataka.tak@gmail.com';
    END IF;
    
    -- 既存のレコードをチェック
    IF EXISTS (SELECT 1 FROM users WHERE id = auth_user_id) THEN
        RAISE NOTICE 'ユーザーレコードは既に存在します';
        RETURN;
    END IF;
    
    -- ランダムな6文字のuser_idを生成
    random_user_id := upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 6));
    
    -- ユーザーレコードを作成
    INSERT INTO users (id, user_id, email, total_purchases, total_referral_earnings, is_active)
    VALUES (auth_user_id, random_user_id, 'masataka.tak@gmail.com', 0, 0, true);
    
    RAISE NOTICE 'ユーザーレコードを作成しました: ID=%, user_id=%', auth_user_id, random_user_id;
END $$;

-- 作成結果を確認
SELECT 
  au.email,
  au.email_confirmed_at IS NOT NULL as email_confirmed,
  u.user_id,
  u.created_at as user_record_created
FROM auth.users au
LEFT JOIN users u ON au.id = u.id
WHERE au.email = 'masataka.tak@gmail.com';
