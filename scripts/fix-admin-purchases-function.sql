-- get_admin_purchases関数のデータ型を修正

DROP FUNCTION IF EXISTS get_admin_purchases();

-- usersテーブルのemailカラムの実際のデータ型を確認
SELECT 
  column_name, 
  data_type, 
  character_maximum_length,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'users' AND column_name = 'email';

-- purchasesテーブルの構造も確認
SELECT 
  column_name, 
  data_type, 
  character_maximum_length,
  is_nullable
FROM information_schema.columns 
WHERE table_name = 'purchases' 
ORDER BY ordinal_position;

-- 修正版の関数を作成（データ型を実際のテーブル構造に合わせる）
CREATE OR REPLACE FUNCTION get_admin_purchases()
RETURNS TABLE (
    id UUID,
    user_id VARCHAR(6),
    email VARCHAR(255),  -- TEXT から VARCHAR(255) に変更
    full_name VARCHAR(255),  -- TEXT から VARCHAR(255) に変更
    nft_quantity INTEGER,
    amount_usd NUMERIC,
    payment_status VARCHAR(50),  -- TEXT から VARCHAR(50) に変更
    admin_approved BOOLEAN,
    admin_approved_at TIMESTAMP WITH TIME ZONE,
    admin_approved_by VARCHAR(255),  -- TEXT から VARCHAR(255) に変更
    payment_proof_url VARCHAR(500),  -- TEXT から VARCHAR(500) に変更
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- テスト実行
SELECT 'Function updated with correct data types' as status;

-- 実際のデータ型を確認するためのテストクエリ
SELECT 
  'Test query - first purchase with user data:' as test,
  p.id,
  u.user_id,
  u.email,
  u.full_name,
  p.payment_status
FROM purchases p
JOIN users u ON p.user_id = u.user_id
LIMIT 1;
