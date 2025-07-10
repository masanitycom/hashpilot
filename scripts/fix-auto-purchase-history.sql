-- auto_purchase_historyテーブルのカラム修正

-- 1. purchasesテーブルの構造を確認
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'purchases' 
ORDER BY ordinal_position;

-- 2. get_auto_purchase_history関数を修正（is_auto_purchaseカラムを使わない）
CREATE OR REPLACE FUNCTION get_auto_purchase_history(
    p_user_id TEXT,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    purchase_id TEXT,
    purchase_date TIMESTAMP WITH TIME ZONE,
    nft_quantity INTEGER,
    amount_usd TEXT,
    cycle_number INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id::TEXT as purchase_id,
        p.created_at as purchase_date,
        p.nft_quantity::INTEGER,
        p.amount_usd::TEXT,
        COALESCE(ac.cycle_number, 1)::INTEGER as cycle_number
    FROM purchases p
    LEFT JOIN affiliate_cycle ac ON p.user_id = ac.user_id
    WHERE p.user_id = p_user_id
    -- is_auto_purchaseカラムの条件を削除
    ORDER BY p.created_at DESC
    LIMIT p_limit;
END;
$$;

-- 3. 権限付与
GRANT EXECUTE ON FUNCTION get_auto_purchase_history(TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_auto_purchase_history(TEXT, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION get_auto_purchase_history(TEXT, INTEGER) TO public;

-- 4. テスト実行
SELECT * FROM get_auto_purchase_history('7A9637', 5);

-- 5. 動作確認
SELECT 'Auto purchase history function updated successfully' as status;