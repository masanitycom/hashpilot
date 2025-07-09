-- 管理者購入ビューを更新して紹介者情報を含める

-- 既存のビューを削除
DROP VIEW IF EXISTS admin_purchases_view CASCADE;

-- 紹介者情報を含む新しいビューを作成
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
    p.nft_sent,
    p.admin_approved,
    p.admin_approved_at,
    p.admin_approved_by,
    p.created_at,
    p.payment_proof_url,
    p.user_notes,
    p.admin_notes
FROM purchases p
LEFT JOIN users u ON p.user_id = u.user_id
LEFT JOIN users ref_user ON u.referrer_user_id = ref_user.user_id
ORDER BY p.created_at DESC;

-- 権限設定
GRANT SELECT ON admin_purchases_view TO authenticated;
GRANT SELECT ON admin_purchases_view TO service_role;

-- 確認クエリ
SELECT 
    user_id,
    email,
    referrer_user_id,
    referrer_email,
    coinw_uid,
    amount_usd,
    payment_status,
    admin_approved
FROM admin_purchases_view 
ORDER BY created_at DESC 
LIMIT 5;
