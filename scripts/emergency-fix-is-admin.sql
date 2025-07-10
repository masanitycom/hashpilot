-- 緊急：is_admin関数の修正

-- 現在のadminsテーブルの状況確認
SELECT 
    'Current admins status' as info,
    email,
    is_active,
    created_at
FROM admins
ORDER BY created_at;

-- basarasystems@gmail.comの状況確認
SELECT 
    'Specific admin check' as info,
    email,
    is_active,
    CASE 
        WHEN is_active = true THEN 'ACTIVE'
        WHEN is_active = false THEN 'INACTIVE'
        ELSE 'NULL'
    END as status
FROM admins
WHERE email = 'basarasystems@gmail.com';

-- is_admin関数を強制的に修正（is_activeチェックを確実に追加）
CREATE OR REPLACE FUNCTION is_admin(user_email text DEFAULT NULL, user_uuid uuid DEFAULT NULL)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  admin_exists BOOLEAN := FALSE;
  check_email TEXT;
  debug_info TEXT := '';
BEGIN
  -- user_emailが提供された場合はそれを使用
  IF user_email IS NOT NULL THEN
    check_email := user_email;
    debug_info := 'Using provided email: ' || user_email;
  -- user_uuidが提供された場合はauth.usersからemailを取得
  ELSIF user_uuid IS NOT NULL THEN
    SELECT email INTO check_email 
    FROM auth.users 
    WHERE id = user_uuid;
    debug_info := 'Retrieved email from UUID: ' || COALESCE(check_email, 'NOT_FOUND');
  -- どちらも提供されない場合は現在のユーザーのemailを使用
  ELSE
    SELECT email INTO check_email 
    FROM auth.users 
    WHERE id = auth.uid();
    debug_info := 'Using current user email: ' || COALESCE(check_email, 'NOT_FOUND');
  END IF;
  
  -- 管理者テーブルにユーザーが存在し、かつis_activeがtrueか確認
  IF check_email IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 
      FROM admins 
      WHERE email = check_email
      AND is_active = true
    ) INTO admin_exists;
    
    -- デバッグログ（本番では削除）
    RAISE NOTICE 'is_admin debug - email: %, admin_exists: %, debug: %', check_email, admin_exists, debug_info;
  END IF;
  
  RETURN admin_exists;
END;
$$;

-- テスト実行
SELECT 
    'Test is_admin function after fix' as info,
    is_admin('basarasystems@gmail.com'::text, NULL::uuid) as admin_check;

-- もしis_activeがfalseになっている場合の修復
UPDATE admins 
SET is_active = true 
WHERE email = 'basarasystems@gmail.com' 
AND is_active != true;