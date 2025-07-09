-- 管理画面用のビューを更新してトランザクションIDを含める
DROP VIEW IF EXISTS admin_purchases_view;

CREATE VIEW admin_purchases_view AS
SELECT 
    p.id,
    p.user_id,
    u.email,
    u.full_name,
    u.coinw_uid,
    u.referrer_user_id,
    ref_user.email as referrer_email,
    ref_user.full_name as referrer_full_name,
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
    u.has_approved_nft
FROM purchases p
LEFT JOIN users u ON p.user_id = u.user_id
LEFT JOIN users ref_user ON u.referrer_user_id = ref_user.user_id
ORDER BY p.created_at DESC;

-- ビューの権限設定
GRANT SELECT ON admin_purchases_view TO authenticated;

SELECT 'Admin purchases view updated with transaction ID support' as status;
