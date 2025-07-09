-- 管理者購入ビューを正しい列名で再作成

-- 1. 既存のビューを削除
DROP VIEW IF EXISTS admin_purchases_view CASCADE;

-- 2. purchasesテーブルの実際の構造に基づいてビューを作成
CREATE VIEW admin_purchases_view AS
SELECT 
    p.id,
    p.user_id,
    u.email as user_email,
    u.coinw_uid,
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
ORDER BY p.created_at DESC;

-- 3. 権限設定
GRANT SELECT ON admin_purchases_view TO authenticated;

-- 4. 確認
SELECT 'Admin purchases view recreated correctly' as status, NOW() as timestamp;
