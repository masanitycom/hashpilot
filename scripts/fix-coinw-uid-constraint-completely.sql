-- CoinW UIDの制約を完全に修正

-- 1. admin_purchases_viewを削除
DROP VIEW IF EXISTS admin_purchases_view;

-- 2. CoinW UIDの型をTEXTに変更
ALTER TABLE users ALTER COLUMN coinw_uid TYPE TEXT;

-- 3. admin_purchases_viewを再作成（正しい列名で）
CREATE VIEW admin_purchases_view AS
SELECT 
    p.id,
    p.user_id,
    u.email as user_email,
    u.coinw_uid,
    p.nft_quantity,
    p.amount_usd,
    p.usdt_address_bep20,
    p.usdt_address_trc20,
    p.payment_status,
    p.nft_sent,
    p.created_at,
    p.confirmed_at,
    p.completed_at,
    p.admin_approved,
    p.admin_approved_at,
    p.admin_approved_by,
    p.payment_proof_url,
    p.user_notes,
    p.admin_notes
FROM purchases p
LEFT JOIN users u ON p.user_id = u.user_id
ORDER BY p.created_at DESC;

-- 4. 確認
SELECT 
    'updated_column_info' as check_type,
    column_name,
    data_type,
    character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'coinw_uid';

SELECT 'coinw_uid_constraint_fixed' as status, NOW() as timestamp;
