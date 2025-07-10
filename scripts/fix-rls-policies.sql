-- RLSポリシーの修正

-- 1. user_daily_profitテーブルのRLSポリシーを確認
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'user_daily_profit';

-- 2. affiliate_cycleテーブルのRLSポリシーを確認
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'affiliate_cycle';

-- 3. RLSを一時的に無効化（テスト用）
-- 注意: 本番環境では推奨されません
ALTER TABLE user_daily_profit DISABLE ROW LEVEL SECURITY;
ALTER TABLE affiliate_cycle DISABLE ROW LEVEL SECURITY;

-- 4. または、適切なRLSポリシーを作成
-- 既存のポリシーを削除
DROP POLICY IF EXISTS "Users can view their own daily profit" ON user_daily_profit;
DROP POLICY IF EXISTS "Users can view their own cycle data" ON affiliate_cycle;

-- 新しいポリシーを作成（認証されたユーザーが自分のデータを見れるように）
CREATE POLICY "Users can view their own daily profit"
ON user_daily_profit
FOR SELECT
TO authenticated
USING (
    auth.uid()::text = user_id 
    OR 
    user_id IN (
        SELECT user_id FROM users WHERE id = auth.uid()
    )
);

CREATE POLICY "Users can view their own cycle data"
ON affiliate_cycle
FOR SELECT
TO authenticated
USING (
    auth.uid()::text = user_id 
    OR 
    user_id IN (
        SELECT user_id FROM users WHERE id = auth.uid()
    )
);

-- 5. 関数のセキュリティも確認
GRANT EXECUTE ON FUNCTION get_auto_purchase_history(TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_auto_purchase_history(TEXT, INTEGER) TO anon;

-- 6. get_auto_purchase_history関数を作成（存在しない場合）
CREATE OR REPLACE FUNCTION get_auto_purchase_history(
    p_user_id TEXT,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    purchase_id TEXT,
    purchase_date TIMESTAMP,
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
        p.nft_quantity,
        p.amount_usd::TEXT,
        COALESCE(ac.cycle_number, 1) as cycle_number
    FROM purchases p
    LEFT JOIN affiliate_cycle ac ON p.user_id = ac.user_id
    WHERE p.user_id = p_user_id
    AND p.is_auto_purchase = true
    ORDER BY p.created_at DESC
    LIMIT p_limit;
END;
$$;

-- 7. 権限付与
GRANT EXECUTE ON FUNCTION get_auto_purchase_history(TEXT, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_auto_purchase_history(TEXT, INTEGER) TO anon;

-- 8. テーブルの権限も確認
GRANT SELECT ON user_daily_profit TO authenticated;
GRANT SELECT ON affiliate_cycle TO authenticated;