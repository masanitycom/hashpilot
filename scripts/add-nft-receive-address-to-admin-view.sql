-- admin_purchases_viewにnft_receive_addressを追加
-- 作成日: 2025年10月9日
-- 目的: 購入詳細モーダルで報酬受取アドレスを表示

-- ビューを再作成（nft_receive_addressを追加）
DROP VIEW IF EXISTS admin_purchases_view;

CREATE VIEW admin_purchases_view AS
SELECT
    p.id,
    p.user_id,
    u.email,
    u.full_name,
    u.coinw_uid,
    u.nft_receive_address,  -- ⭐ 追加
    u.referrer_user_id,
    ref.email as referrer_email,
    ref.full_name as referrer_full_name,
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
    u.has_approved_nft,
    p.is_auto_purchase
FROM purchases p
INNER JOIN users u ON p.user_id = u.user_id
LEFT JOIN users ref ON u.referrer_user_id = ref.user_id
-- 自動購入を除外（手動購入のみ表示）
WHERE COALESCE(p.is_auto_purchase, FALSE) = FALSE
ORDER BY p.created_at DESC;

-- 権限付与
GRANT SELECT ON admin_purchases_view TO anon;
GRANT SELECT ON admin_purchases_view TO authenticated;

-- 確認
SELECT
    '✅ admin_purchases_view updated with nft_receive_address' as message;

-- サンプルデータ確認（最新5件）
SELECT
    user_id,
    email,
    nft_receive_address,
    created_at
FROM admin_purchases_view
ORDER BY created_at DESC
LIMIT 5;
