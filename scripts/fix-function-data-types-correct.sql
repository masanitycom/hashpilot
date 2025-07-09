-- 実際のテーブル構造に基づいて関数を完全に修正

-- 既存の関数を削除
DROP FUNCTION IF EXISTS get_admin_purchases();

-- 実際のデータ型に完全に合わせた関数を作成
CREATE OR REPLACE FUNCTION get_admin_purchases()
RETURNS TABLE (
    id UUID,
    user_id CHARACTER VARYING(6),  -- usersテーブルのuser_idの実際の型
    email CHARACTER VARYING(255),  -- usersテーブルのemailの実際の型
    full_name CHARACTER VARYING(255),  -- usersテーブルのfull_nameの実際の型
    nft_quantity INTEGER,
    amount_usd NUMERIC,
    payment_status CHARACTER VARYING(50),  -- purchasesテーブルのpayment_statusの実際の型
    admin_approved BOOLEAN,
    admin_approved_at TIMESTAMP WITH TIME ZONE,
    admin_approved_by CHARACTER VARYING(255),  -- 実際の型に合わせる
    payment_proof_url CHARACTER VARYING(500),  -- 実際の型に合わせる
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
    
    -- 全ての購入データを返す（型キャストを明示的に行う）
    RETURN QUERY
    SELECT 
        p.id,
        u.user_id::CHARACTER VARYING(6),
        u.email::CHARACTER VARYING(255),
        u.full_name::CHARACTER VARYING(255),
        p.nft_quantity,
        p.amount_usd,
        p.payment_status::CHARACTER VARYING(50),
        p.admin_approved,
        p.admin_approved_at,
        p.admin_approved_by::CHARACTER VARYING(255),
        p.payment_proof_url::CHARACTER VARYING(500),
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

-- 関数のテスト実行
SELECT 'Testing function execution:' as test;
SELECT * FROM get_admin_purchases() LIMIT 1;
