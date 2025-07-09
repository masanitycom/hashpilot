-- CoinW UIDの文字数制限を再度修正

-- 1. 現在の制限確認
SELECT 
    'current_limit' as check_type,
    column_name,
    character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'coinw_uid';

-- 2. ビューを削除
DROP VIEW IF EXISTS admin_purchases_view;

-- 3. CoinW UIDの制限を拡張
ALTER TABLE users 
ALTER COLUMN coinw_uid TYPE VARCHAR(50);

-- 4. ビューを再作成
CREATE VIEW admin_purchases_view AS
SELECT 
    p.id,
    p.user_id,
    u.email,
    u.coinw_uid,
    p.nft_quantity,
    p.amount_usd,
    p.payment_status,
    p.admin_approved,
    p.admin_approved_at,
    p.admin_approved_by,
    p.created_at,
    p.admin_notes
FROM purchases p
LEFT JOIN users u ON p.user_id = u.user_id
ORDER BY p.created_at DESC;

-- 5. 確認
SELECT 
    'updated_limit' as check_type,
    column_name,
    character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'coinw_uid';

SELECT 'coinw_uid_limit_fixed' as status, NOW() as timestamp;
