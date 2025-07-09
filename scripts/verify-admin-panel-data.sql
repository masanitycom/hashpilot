-- 管理画面データ表示確認

-- 1. 管理画面で表示されるユーザーデータ
SELECT 
    'admin_panel_test' as check_type,
    user_id,
    email,
    coinw_uid,
    referrer_user_id,
    total_purchases,
    is_active,
    has_approved_nft,
    created_at
FROM users 
ORDER BY created_at DESC 
LIMIT 10;

-- 2. admin_purchases_viewの動作確認
SELECT 
    'admin_purchases_view_test' as check_type,
    user_id,
    user_email,
    coinw_uid,
    referrer_user_id,
    nft_quantity,
    amount_usd,
    payment_status
FROM admin_purchases_view
LIMIT 5;

-- 3. 管理者関数の型確認
SELECT * FROM get_admin_users() LIMIT 5;
