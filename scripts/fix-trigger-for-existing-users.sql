-- 既存の確認済みユーザーで、usersレコードが不足している場合の一括修正
DO $$
DECLARE
    user_record RECORD;
    random_user_id text;
BEGIN
    -- 確認済みだがusersレコードがないユーザーを検索
    FOR user_record IN 
        SELECT au.id, au.email
        FROM auth.users au
        LEFT JOIN users u ON au.id = u.id
        WHERE au.email_confirmed_at IS NOT NULL 
        AND u.id IS NULL
    LOOP
        -- ランダムな6文字のuser_idを生成
        random_user_id := upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 6));
        
        -- ユーザーレコードを作成
        INSERT INTO users (id, user_id, email, total_purchases, total_referral_earnings, is_active)
        VALUES (user_record.id, random_user_id, user_record.email, 0, 0, true);
        
        RAISE NOTICE '修正完了: % (user_id: %)', user_record.email, random_user_id;
    END LOOP;
END $$;

-- 修正結果を確認
SELECT 
  au.email,
  au.email_confirmed_at IS NOT NULL as email_confirmed,
  u.user_id IS NOT NULL as has_user_record,
  u.user_id
FROM auth.users au
LEFT JOIN users u ON au.id = u.id
WHERE au.email_confirmed_at IS NOT NULL
ORDER BY au.created_at DESC;
