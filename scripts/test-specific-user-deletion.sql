-- エラーが発生したユーザーAA8D9Bの削除テスト

-- 1. 削除対象ユーザーの詳細確認
SELECT 
    '🔍 削除対象ユーザー詳細:' as info,
    u.id as uuid_id,
    u.user_id as short_id,
    u.email,
    u.total_purchases,
    u.has_approved_nft,
    u.created_at
FROM users u
WHERE u.user_id = 'AA8D9B';

-- 2. 関連データの確認
SELECT 
    '🔍 関連データの確認:' as info,
    'affiliate_cycle' as table_name,
    COUNT(*) as record_count,
    jsonb_agg(jsonb_build_object('user_id', user_id, 'phase', phase, 'total_nft_count', total_nft_count)) as records
FROM affiliate_cycle 
WHERE user_id = 'AA8D9B'
UNION ALL
SELECT 
    '🔍 関連データの確認:' as info,
    'purchases' as table_name,
    COUNT(*) as record_count,
    jsonb_agg(jsonb_build_object('user_id', user_id, 'amount_usd', amount_usd, 'admin_approved', admin_approved)) as records
FROM purchases 
WHERE user_id = 'AA8D9B'
UNION ALL
SELECT 
    '🔍 関連データの確認:' as info,
    'referrer_relations' as table_name,
    COUNT(*) as record_count,
    jsonb_agg(jsonb_build_object('user_id', user_id, 'email', email)) as records
FROM users 
WHERE referrer_user_id = 'AA8D9B';

-- 3. 削除関数の実行テスト（実際に削除されます！）
-- 注意: 以下のコメントを外す前に、本当に削除してよいか確認してください
-- SELECT * FROM delete_user_safely('AA8D9B', 'masataka.tak@gmail.com');

-- 4. より安全なテストユーザーで試す場合
SELECT 
    '💡 より安全なテストユーザー候補:' as info,
    user_id,
    email,
    total_purchases,
    has_approved_nft
FROM users 
WHERE email LIKE '%test%' 
   OR (created_at > NOW() - INTERVAL '1 day' AND COALESCE(total_purchases, 0) = 0)
ORDER BY created_at DESC
LIMIT 3;

-- 5. テストユーザーでの削除実行（安全）
-- SELECT * FROM delete_user_safely('AB337A', 'masataka.tak@gmail.com');