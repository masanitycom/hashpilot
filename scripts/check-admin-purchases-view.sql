-- admin_purchases_viewの確認

-- ビューの定義確認
SELECT 
    'View definition' as info,
    pg_get_viewdef('admin_purchases_view') as definition;

-- ビューから最新データを取得
SELECT 
    'View data for 2A973B' as info,
    *
FROM admin_purchases_view 
WHERE user_id = '2A973B'
ORDER BY created_at DESC;

-- 直接テーブルとビューの比較
SELECT 
    'Direct table vs view comparison' as info,
    'TABLE' as source,
    id,
    user_id,
    admin_approved,
    payment_status,
    created_at
FROM purchases 
WHERE user_id = '2A973B'
UNION ALL
SELECT 
    'Direct table vs view comparison' as info,
    'VIEW' as source,
    id,
    user_id,
    admin_approved::boolean,
    payment_status,
    created_at
FROM admin_purchases_view 
WHERE user_id = '2A973B'
ORDER BY created_at DESC;