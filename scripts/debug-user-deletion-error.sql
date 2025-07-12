-- ユーザー削除エラーのデバッグ

-- 1. エラーが発生したUUIDのユーザー情報を確認
SELECT 
    id as uuid_id,
    user_id as short_id,
    email,
    created_at,
    has_approved_nft,
    total_purchases
FROM users
WHERE id::text = '3b157508-937c-48d7-95db-82b0574b8c4f';

-- 2. そのユーザーのaffiliate_cycleレコードを確認
WITH target_user AS (
    SELECT user_id FROM users WHERE id::text = '3b157508-937c-48d7-95db-82b0574b8c4f'
)
SELECT 
    ac.*
FROM affiliate_cycle ac, target_user tu
WHERE ac.user_id = tu.user_id;

-- 3. 削除関数のテスト（実際には削除しない）
WITH target_user AS (
    SELECT user_id, email FROM users WHERE id::text = '3b157508-937c-48d7-95db-82b0574b8c4f'
)
SELECT 
    'テスト: 以下のユーザーを削除します' as info,
    tu.user_id,
    tu.email,
    '実行コマンド: SELECT * FROM delete_user_safely(''' || tu.user_id || ''', ''masataka.tak@gmail.com'');' as command
FROM target_user tu;