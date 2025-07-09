-- 管理者関数の重複問題を解決

-- 1. 既存のis_admin関数をすべて削除
DROP FUNCTION IF EXISTS is_admin(text);
DROP FUNCTION IF EXISTS is_admin(text, uuid);

-- 2. 新しいis_admin関数を作成（シンプル版）
CREATE OR REPLACE FUNCTION is_admin(user_email TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    admin_exists BOOLEAN := FALSE;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM admins 
        WHERE email = user_email 
        AND is_active = true
    ) INTO admin_exists;
    
    RETURN admin_exists;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$;

-- 3. 関数の実行権限を設定
GRANT EXECUTE ON FUNCTION is_admin(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin(TEXT) TO anon;

-- 4. テスト実行
SELECT 
    'Admin Function Test' as check_type,
    is_admin('basarasystems@gmail.com') as is_admin_result;

-- 5. 現在の管理者一覧を確認
SELECT 
    'Current Admins Check' as check_type,
    email,
    is_active
FROM admins
WHERE is_active = true;
