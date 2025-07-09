-- データベース構造の修正

-- 1. coinw_uidカラムをusersテーブルに追加
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS coinw_uid VARCHAR(255);

-- 2. is_admin関数を修正（引数の型を統一）
DROP FUNCTION IF EXISTS public.is_admin(uuid);
DROP FUNCTION IF EXISTS public.is_admin(text);

CREATE OR REPLACE FUNCTION public.is_admin(user_email TEXT DEFAULT NULL, user_uuid UUID DEFAULT NULL)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  admin_exists BOOLEAN := FALSE;
  check_email TEXT;
BEGIN
  -- user_emailが提供された場合はそれを使用
  IF user_email IS NOT NULL THEN
    check_email := user_email;
  -- user_uuidが提供された場合はauth.usersからemailを取得
  ELSIF user_uuid IS NOT NULL THEN
    SELECT email INTO check_email 
    FROM auth.users 
    WHERE id = user_uuid;
  -- どちらも提供されない場合は現在のユーザーのemailを使用
  ELSE
    SELECT email INTO check_email 
    FROM auth.users 
    WHERE id = auth.uid();
  END IF;
  
  -- 管理者テーブルにユーザーが存在するか確認
  IF check_email IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 
      FROM admins 
      WHERE email = check_email
    ) INTO admin_exists;
  END IF;
  
  RETURN admin_exists;
END;
$$;

-- 3. RLSポリシーを修正（is_admin関数の呼び出し方を修正）
DROP POLICY IF EXISTS "Admins can view all data" ON public.users;
DROP POLICY IF EXISTS "Admins can view all purchases" ON public.purchases;

-- 管理者は全データアクセス可能（修正版）
CREATE POLICY "Admins can view all data" ON public.users
  FOR ALL USING (
    auth.uid() = user_id::uuid OR 
    public.is_admin(NULL, auth.uid())
  );

CREATE POLICY "Admins can view all purchases" ON public.purchases
  FOR ALL USING (
    auth.uid() = user_id::uuid OR 
    public.is_admin(NULL, auth.uid())
  );

-- 4. ユーザー作成トリガーを修正（coinw_uidを含める）
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (
    id, 
    user_id, 
    email, 
    full_name,
    referrer_user_id,
    coinw_uid,
    created_at,
    is_active
  )
  VALUES (
    gen_random_uuid(),
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.raw_user_meta_data->>'referrer_user_id',
    NEW.raw_user_meta_data->>'coinw_uid',
    NOW(),
    true
  );
  RETURN NEW;
EXCEPTION
  WHEN others THEN
    -- エラーが発生してもユーザー作成は続行
    RAISE WARNING 'ユーザーレコード作成でエラー: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. 既存のトリガーを削除して再作成
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 6. 管理者テーブルが存在することを確認
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'admins'
  ) THEN
    CREATE TABLE admins (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      email TEXT NOT NULL UNIQUE,
      role TEXT DEFAULT 'admin',
      is_active BOOLEAN DEFAULT true,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );
  END IF;
END
$$;

-- 7. 管理者データを確認・追加
INSERT INTO admins (email, role, is_active)
VALUES 
  ('masataka.tak@gmail.com', 'super_admin', true),
  ('admin@hashpilot.com', 'super_admin', true),
  ('basarasystems@gmail.com', 'admin', true)
ON CONFLICT (email) DO UPDATE SET
  is_active = EXCLUDED.is_active,
  role = EXCLUDED.role;

-- 8. 現在のデータベース状況を確認
SELECT 'データベース修正完了' as status;

-- usersテーブルの最新構造を確認
SELECT 
  'usersテーブル構造（修正後）' as check_type,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'users'
ORDER BY ordinal_position;

-- 管理者データを確認
SELECT 'admins確認' as check_type, * FROM admins;

-- is_admin関数のテスト
SELECT 
  'is_admin関数テスト' as check_type,
  public.is_admin('masataka.tak@gmail.com') as test_result;
