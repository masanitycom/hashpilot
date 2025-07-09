-- 重複したユーザーレコードを削除
DELETE FROM users a USING users b 
WHERE a.id = b.id AND a.ctid < b.ctid;

-- トリガー関数を修正（重複防止）
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    random_user_id text;
    existing_user_count integer;
BEGIN
    -- 既存のレコードをチェック
    SELECT COUNT(*) INTO existing_user_count 
    FROM public.users 
    WHERE id = new.id;
    
    -- 既にレコードが存在する場合は何もしない
    IF existing_user_count > 0 THEN
        RETURN new;
    END IF;
    
    -- ランダムな6文字のuser_idを生成
    random_user_id := upper(substring(md5(random()::text) from 1 for 6));
    
    -- usersテーブルに新しいレコードを挿入
    INSERT INTO public.users (id, user_id, email, total_purchases, total_referral_earnings, is_active)
    VALUES (new.id, random_user_id, new.email, 0, 0, true);
    
    RETURN new;
EXCEPTION
    WHEN unique_violation THEN
        -- 重複エラーの場合は無視
        RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
