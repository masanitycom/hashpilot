-- V1SPIYユーザーのCoinW UIDを実際の値に更新

-- 現在の状態確認
SELECT 
    'before_update' as status,
    user_id,
    email,
    coinw_uid
FROM users 
WHERE user_id = 'V1SPIY';

-- 実際のCoinW UIDに更新（値は管理者が指定）
-- UPDATE users 
-- SET coinw_uid = '実際のCoinW_UID値',
--     updated_at = NOW()
-- WHERE user_id = 'V1SPIY';

-- 更新後の確認
-- SELECT 
--     'after_update' as status,
--     user_id,
--     email,
--     coinw_uid
-- FROM users 
-- WHERE user_id = 'V1SPIY';

-- 管理画面での表示確認
SELECT 
    'admin_view_updated' as check_type,
    user_id,
    email,
    coinw_uid,
    amount_usd
FROM admin_purchases_view 
WHERE user_id = 'V1SPIY';
