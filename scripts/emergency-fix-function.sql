-- 緊急修正：関数を完全に削除して再作成

-- 既存の関数を完全に削除
DROP FUNCTION IF EXISTS get_admin_purchases();

-- シンプルな管理者用ビューを作成（関数の代わり）
DROP VIEW IF EXISTS admin_purchases_view;

CREATE VIEW admin_purchases_view AS
SELECT 
    p.id,
    u.user_id,
    u.email,
    u.full_name,
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
    p.confirmed_at,
    p.completed_at,
    u.has_approved_nft
FROM purchases p
JOIN users u ON p.user_id = u.user_id
ORDER BY p.created_at DESC;

-- ビューのテスト
SELECT 'Testing view:' as test;
SELECT * FROM admin_purchases_view LIMIT 1;
