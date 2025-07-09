-- 管理者用関数のデータ型を修正

DROP FUNCTION IF EXISTS get_admin_purchases();

CREATE OR REPLACE FUNCTION get_admin_purchases()
RETURNS TABLE (
    id UUID,
    user_id VARCHAR(6),  -- TEXT から VARCHAR(6) に変更
    email TEXT,
    full_name TEXT,
    nft_quantity INTEGER,
    amount_usd NUMERIC,
    payment_status TEXT,
    admin_approved BOOLEAN,
    admin_approved_at TIMESTAMP WITH TIME ZONE,
    admin_approved_by TEXT,
    payment_proof_url TEXT,
    user_notes TEXT,
    admin_notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    confirmed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    has_approved_nft BOOLEAN
) AS $$
BEGIN
    -- 管理者権限チェック
    IF NOT EXISTS (
        SELECT 1 FROM admins a 
        JOIN users u ON u.email = a.email
        WHERE u.id = auth.uid() AND a.is_active = TRUE
    ) THEN
        RAISE EXCEPTION '管理者権限が必要です';
    END IF;
    
    -- 全ての購入データを返す
    RETURN QUERY
    SELECT 
        p.id,
        u.user_id,  -- VARCHAR(6)型
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- テスト実行
SELECT 'Function updated successfully' as status;
