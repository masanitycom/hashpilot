-- usersテーブルにcoinw_uidカラムを追加
ALTER TABLE users ADD COLUMN IF NOT EXISTS coinw_uid TEXT;

-- 管理者用のビューを更新してcoinw_uidを含める
DROP VIEW IF EXISTS admin_purchases_view;

CREATE VIEW admin_purchases_view AS
SELECT 
    p.id,
    p.user_id,
    u.email,
    u.full_name,
    u.coinw_uid,
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
    CASE WHEN p.admin_approved = true THEN true ELSE false END as has_approved_nft
FROM purchases p
LEFT JOIN users u ON p.user_id = u.user_id
ORDER BY p.created_at DESC;

-- 管理者権限の確認
GRANT SELECT ON admin_purchases_view TO authenticated;
