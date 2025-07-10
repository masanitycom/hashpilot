-- is_admin関数のテスト（明示的なキャスト）

-- 既存の関数を確認
SELECT 
    'All is_admin functions' as info,
    proname,
    proargnames,
    proargtypes::regtype[]
FROM pg_proc 
WHERE proname = 'is_admin';

-- 明示的なキャストでテスト
SELECT 
    'Test with explicit cast' as info,
    is_admin('basarasystems@gmail.com'::text, NULL::uuid) as admin_check;

-- 別のテスト方法
SELECT 
    'Test with function call' as info,
    (SELECT is_admin(user_email => 'basarasystems@gmail.com')) as admin_check;