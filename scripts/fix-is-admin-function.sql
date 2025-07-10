-- is_admin関数を修正（is_activeチェックを追加）

-- 既存の関数を削除
DROP FUNCTION IF EXISTS is_admin(text);
DROP FUNCTION IF EXISTS is_admin(text, uuid);

-- 新しいis_admin関数を作成
CREATE OR REPLACE FUNCTION is_admin(user_email text DEFAULT NULL, user_uuid uuid DEFAULT NULL)
RETURNS boolean
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
  
  -- 管理者テーブルにユーザーが存在し、かつis_activeがtrueか確認
  IF check_email IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 
      FROM admins 
      WHERE email = check_email
      AND is_active = true
    ) INTO admin_exists;
  END IF;
  
  RETURN admin_exists;
END;
$$;

-- 実行権限を付与
GRANT EXECUTE ON FUNCTION is_admin(text, uuid) TO anon;
GRANT EXECUTE ON FUNCTION is_admin(text, uuid) TO authenticated;

-- テスト実行
SELECT 
    'Test is_admin function' as info,
    is_admin('basarasystems@gmail.com'::text) as admin_check;