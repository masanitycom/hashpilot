-- 管理者関数の戻り値型を修正

-- 1. 既存の関数を削除
DROP FUNCTION IF EXISTS get_admin_users();

-- 2. 正しい戻り値型で関数を再作成
CREATE OR REPLACE FUNCTION get_admin_users()
RETURNS TABLE (
    user_id TEXT,  -- VARCHAR(6) から TEXT に変更
    email TEXT,
    coinw_uid TEXT,
    referrer_user_id TEXT,  -- VARCHAR から TEXT に変更
    total_purchases NUMERIC,
    is_active BOOLEAN,
    has_approved_nft BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE
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
    
    -- ユーザーデータを返す
    RETURN QUERY
    SELECT 
        u.user_id::TEXT,  -- TEXT型にキャスト
        u.email,
        u.coinw_uid,
        u.referrer_user_id::TEXT,  -- TEXT型にキャスト
        COALESCE(u.total_purchases, 0) as total_purchases,
        u.is_active,
        u.has_approved_nft,
        u.created_at
    FROM users u
    ORDER BY u.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. 管理者購入関数も修正
DROP FUNCTION IF EXISTS get_admin_purchases();

CREATE OR REPLACE FUNCTION get_admin_purchases()
RETURNS TABLE (
    id UUID,
    user_id TEXT,  -- VARCHAR(6) から TEXT に変更
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
        u.user_id::TEXT,  -- TEXT型にキャスト
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

SELECT 'Admin functions fixed with correct return types' as status;
