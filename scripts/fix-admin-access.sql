-- 管理者アクセス権限を修正するスクリプト

-- 既存の管理者関数を確認
SELECT routine_name, data_type
FROM information_schema.routines
WHERE routine_name = 'is_admin';

-- is_admin関数を修正（存在する場合は置き換え）
CREATE OR REPLACE FUNCTION is_admin(user_email TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  admin_exists BOOLEAN;
BEGIN
  -- 管理者テーブルにユーザーが存在するか確認
  SELECT EXISTS (
    SELECT 1 
    FROM admins 
    WHERE email = user_email
  ) INTO admin_exists;
  
  RETURN admin_exists;
END;
$$;

-- 管理者テーブルが存在するか確認
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'admins'
  ) THEN
    -- 管理者テーブルが存在しない場合は作成
    CREATE TABLE admins (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      email TEXT NOT NULL UNIQUE,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
    );
  END IF;
END
$$;

-- 現在のユーザーを管理者として追加（テスト用）
-- 注意: 本番環境では特定の管理者のみを追加すること
INSERT INTO admins (email)
SELECT auth.users.email
FROM auth.users
WHERE NOT EXISTS (
  SELECT 1 FROM admins WHERE admins.email = auth.users.email
)
AND auth.users.email IS NOT NULL;

-- 管理者が正しく追加されたか確認
SELECT * FROM admins;
