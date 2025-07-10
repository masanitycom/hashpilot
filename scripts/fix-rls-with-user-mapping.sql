-- RLSポリシーを正しく修正（user_idマッピングを考慮）

-- 1. 既存のポリシーを削除
DROP POLICY IF EXISTS "user_daily_profit_select" ON user_daily_profit;
DROP POLICY IF EXISTS "affiliate_cycle_select" ON affiliate_cycle;

-- 2. 新しいポリシーを作成（usersテーブルとの結合を使用）
CREATE POLICY "user_daily_profit_select"
ON user_daily_profit
FOR SELECT
TO public
USING (
    user_id IN (
        SELECT user_id FROM users WHERE id = auth.uid()
    )
    OR 
    EXISTS (
        SELECT 1 FROM admins WHERE user_id = auth.uid()::text
    )
);

CREATE POLICY "affiliate_cycle_select"
ON affiliate_cycle
FOR SELECT
TO public
USING (
    user_id IN (
        SELECT user_id FROM users WHERE id = auth.uid()
    )
    OR 
    EXISTS (
        SELECT 1 FROM admins WHERE user_id = auth.uid()::text
    )
);

-- 3. get_auto_purchase_history関数を作成
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
    AND COALESCE(p.is_auto_purchase, false) = true
    ORDER BY p.created_at DESC
    LIMIT p_limit;
END;
$$;

-- 4. 権限付与
GRANT EXECUTE ON FUNCTION get_auto_purchase_history(TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_auto_purchase_history(TEXT, INTEGER) TO anon;
GRANT EXECUTE ON FUNCTION get_auto_purchase_history(TEXT, INTEGER) TO public;

-- 5. テスト: 特定ユーザーのマッピングを確認
SELECT 
    u.id as auth_id,
    u.user_id,
    u.email,
    udp.date,
    udp.daily_profit
FROM users u
LEFT JOIN user_daily_profit udp ON u.user_id = udp.user_id
WHERE u.id = '7241f7f8-d05f-4c62-ac32-c2f8d8a93323'
ORDER BY udp.date DESC
LIMIT 5;

-- 6. 動作確認
SELECT 'RLS policies updated successfully' as status;