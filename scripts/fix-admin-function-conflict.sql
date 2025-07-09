-- 管理者関数の競合を解決

-- 1. 1パラメータ版のis_admin関数を削除（CASCADE付き）
DROP FUNCTION IF EXISTS is_admin(text) CASCADE;

-- 2. 2パラメータ版のis_admin関数が正しく動作するか確認
DO $$
DECLARE
    user_uuid uuid;
    admin_result boolean;
BEGIN
    -- basarasystems@gmail.comのUUIDを取得
    SELECT id INTO user_uuid 
    FROM auth.users 
    WHERE email = 'basarasystems@gmail.com';
    
    IF user_uuid IS NOT NULL THEN
        -- 2パラメータ版の関数をテスト
        SELECT is_admin('basarasystems@gmail.com', user_uuid) INTO admin_result;
        RAISE NOTICE 'basarasystems@gmail.com Admin Test Result: %', admin_result;
    ELSE
        RAISE NOTICE 'User UUID not found for basarasystems@gmail.com';
    END IF;
END $$;

-- 3. 削除されたRLSポリシーを再作成
-- usersテーブルのポリシー
DROP POLICY IF EXISTS "Admins can view all data" ON users;
CREATE POLICY "Admins can view all data" ON users
FOR ALL TO authenticated
USING (is_admin(auth.jwt() ->> 'email', auth.uid()));

-- purchasesテーブルのポリシー
DROP POLICY IF EXISTS "Admins can view all purchases" ON purchases;
CREATE POLICY "Admins can view all purchases" ON purchases
FOR ALL TO authenticated
USING (is_admin(auth.jwt() ->> 'email', auth.uid()));

-- 4. 現在の関数状況を確認
SELECT 
    'Final Function Check' as check_type,
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname = 'is_admin'
AND n.nspname = 'public';
