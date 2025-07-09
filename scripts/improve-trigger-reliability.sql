-- より信頼性の高いトリガー関数に更新
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
    random_user_id text;
    existing_user_count integer;
    retry_count integer := 0;
    max_retries integer := 3;
BEGIN
    -- 既存のレコードをチェック
    SELECT COUNT(*) INTO existing_user_count 
    FROM public.users 
    WHERE id = new.id;
    
    -- 既にレコードが存在する場合は何もしない
    IF existing_user_count > 0 THEN
        RAISE NOTICE 'ユーザーレコードは既に存在します: %', new.email;
        RETURN new;
    END IF;
    
    -- リトライループでユニークなuser_idを生成
    WHILE retry_count < max_retries LOOP
        -- ランダムな6文字のuser_idを生成
        random_user_id := upper(substring(md5(random()::text || clock_timestamp()::text || retry_count::text) from 1 for 6));
        
        -- user_idの重複チェック
        SELECT COUNT(*) INTO existing_user_count 
        FROM public.users 
        WHERE user_id = random_user_id;
        
        -- ユニークな場合は挿入を試行
        IF existing_user_count = 0 THEN
            BEGIN
                INSERT INTO public.users (id, user_id, email, total_purchases, total_referral_earnings, is_active)
                VALUES (new.id, random_user_id, COALESCE(new.email, ''), 0, 0, true);
                
                RAISE NOTICE 'ユーザーレコード作成成功: % (user_id: %)', new.email, random_user_id;
                RETURN new;
            EXCEPTION
                WHEN unique_violation THEN
                    retry_count := retry_count + 1;
                    RAISE NOTICE 'ユニーク制約違反、リトライ中: % (試行回数: %)', new.email, retry_count;
                    CONTINUE;
            END;
        ELSE
            retry_count := retry_count + 1;
        END IF;
    END LOOP;
    
    -- 最大リトライ回数に達した場合
    RAISE WARNING 'ユーザーレコード作成に失敗しました（最大リトライ回数到達）: %', new.email;
    RETURN new;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'ユーザーレコード作成中にエラーが発生: % - %', new.email, SQLERRM;
        RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- トリガーを再作成
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- トリガーの状態確認
SELECT 
  trigger_name,
  event_manipulation,
  action_timing,
  action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'on_auth_user_created';
