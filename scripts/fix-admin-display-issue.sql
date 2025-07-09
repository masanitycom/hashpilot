-- 管理画面表示問題を修正

-- 1. admin_purchases_viewを削除して再作成
DROP VIEW IF EXISTS admin_purchases_view CASCADE;

-- 2. 正しいadmin_purchases_viewを作成
CREATE VIEW admin_purchases_view AS
SELECT 
    p.id,
    p.user_id,
    u.email as user_email,
    u.coinw_uid,
    u.referrer_user_id,
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

-- 3. 管理者用のユーザー一覧関数を修正
CREATE OR REPLACE FUNCTION get_admin_users()
RETURNS TABLE (
    user_id TEXT,
    email TEXT,
    coinw_uid TEXT,
    referrer_user_id TEXT,
    total_purchases NUMERIC,
    is_active BOOLEAN,
    has_approved_nft BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id,
        u.email,
        u.coinw_uid,
        u.referrer_user_id,
        COALESCE(u.total_purchases, 0) as total_purchases,
        u.is_active,
        u.has_approved_nft,
        u.created_at
    FROM users u
    ORDER BY u.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. 確認
SELECT 'Admin display issue fixed' as status, NOW() as timestamp;
