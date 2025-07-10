-- is_admin function を確認・作成

-- 既存の関数を確認
SELECT 
    'Existing is_admin functions' as info,
    proname,
    prosrc,
    proargnames
FROM pg_proc 
WHERE proname = 'is_admin';

-- admins テーブルの確認
SELECT 
    'Admins table check' as info,
    email,
    is_active
FROM admins
WHERE is_active = true;

-- is_admin 関数を作成（存在しない場合）
CREATE OR REPLACE FUNCTION is_admin(user_email text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM admins 
        WHERE email = user_email 
        AND is_active = true
    );
END;
$$;

-- 実行権限を付与
GRANT EXECUTE ON FUNCTION is_admin(text) TO anon;
GRANT EXECUTE ON FUNCTION is_admin(text) TO authenticated;

-- テスト実行
SELECT 
    'Test is_admin function' as info,
    is_admin('basarasystems@gmail.com') as admin_check;