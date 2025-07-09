-- 管理者購入ビューを修正してCoinW UIDを含める

-- 既存のビューを削除
DROP VIEW IF EXISTS admin_purchases_view;

-- 新しいビューを作成（CoinW UIDを含む）
CREATE VIEW admin_purchases_view AS
SELECT 
    p.id,
    p.user_id,
    u.email,
    u.full_name,
    u.coinw_uid,  -- CoinW UIDを追加
    p.nft_quantity,
    p.amount_usd,
    p.payment_status,
    p.admin_approved,
    p.admin_approved_at,
    p.admin_approved_by,
    p.payment_proof_url,
    p.user_notes,
    p.admin_notes,
    p.created_at,
    CASE 
        WHEN p.admin_approved = true THEN true
        ELSE false
    END as has_approved_nft
FROM purchases p
LEFT JOIN users u ON p.user_id = u.user_id;

-- ビューの権限設定
GRANT SELECT ON admin_purchases_view TO authenticated;
GRANT SELECT ON admin_purchases_view TO service_role;

-- 確認クエリ
SELECT 
    user_id,
    email,
    coinw_uid,
    amount_usd,
    payment_status,
    admin_approved
FROM admin_purchases_view 
ORDER BY created_at DESC 
LIMIT 10;
