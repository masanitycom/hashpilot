-- 認証関連の問題を修正（簡略版）

-- 1. ユーザー作成トリガーを一時的に無効化
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- 2. 簡単なユーザー作成トリガーを再作成
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (
    id, 
    user_id, 
    email, 
    full_name,
    referrer_user_id,
    coinw_uid
  )
  VALUES (
    gen_random_uuid(),
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.raw_user_meta_data->>'referrer_user_id',
    NEW.raw_user_meta_data->>'coinw_uid'
  );
  RETURN NEW;
EXCEPTION
  WHEN others THEN
    -- エラーが発生してもユーザー作成は続行
    RAISE WARNING 'ユーザーレコード作成でエラー: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. トリガーを再作成
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. RLSポリシーを一時的に無効化（テスト用）
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchases DISABLE ROW LEVEL SECURITY;

-- 5. 基本的なRLSポリシーを再設定
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;

-- 既存のポリシーを削除
DROP POLICY IF EXISTS "Users can view own data" ON public.users;
DROP POLICY IF EXISTS "Users can view own purchases" ON public.purchases;
DROP POLICY IF EXISTS "Admins can view all data" ON public.users;
DROP POLICY IF EXISTS "Admins can view all purchases" ON public.purchases;

-- ユーザーは自分のデータのみアクセス可能
CREATE POLICY "Users can view own data" ON public.users
  FOR ALL USING (auth.uid() = user_id::uuid);

-- 購入データも同様
CREATE POLICY "Users can view own purchases" ON public.purchases
  FOR ALL USING (auth.uid() = user_id::uuid);

-- 管理者は全データアクセス可能
CREATE POLICY "Admins can view all data" ON public.users
  FOR ALL USING (public.is_admin(auth.uid()));

CREATE POLICY "Admins can view all purchases" ON public.purchases
  FOR ALL USING (public.is_admin(auth.uid()));
