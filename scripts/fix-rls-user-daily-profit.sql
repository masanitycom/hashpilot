-- ========================================
-- user_daily_profitテーブルのRLSポリシー修正
-- フロントエンドからの既存データ読み取りを許可
-- ========================================

-- 1. 現在のRLSポリシー確認
SELECT 
    '=== 現在のRLSポリシー ===' as info,
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

-- 2. 既存のRLSポリシーを削除
DROP POLICY IF EXISTS "Users can read their own daily profit" ON user_daily_profit;
DROP POLICY IF EXISTS "Enable read for authenticated users" ON user_daily_profit;
DROP POLICY IF EXISTS "Enable read access for own data" ON user_daily_profit;

-- 3. 新しいRLSポリシーを作成（認証済みユーザーは自分のデータを読み取り可能）
CREATE POLICY "authenticated_users_read_own_daily_profit" ON user_daily_profit
    FOR SELECT
    TO authenticated
    USING (
        user_id = auth.uid()::text
        OR 
        -- 管理者は全データアクセス可能
        EXISTS (
            SELECT 1 FROM admins 
            WHERE user_id = auth.uid()::text
        )
    );

-- 4. anonユーザーにも読み取り権限を付与（一時的）
CREATE POLICY "anon_users_read_daily_profit" ON user_daily_profit
    FOR SELECT
    TO anon
    USING (true);

-- 5. RLSが有効であることを確認
ALTER TABLE user_daily_profit ENABLE ROW LEVEL SECURITY;

-- 6. テーブル権限を確認・付与
GRANT SELECT ON user_daily_profit TO authenticated;
GRANT SELECT ON user_daily_profit TO anon;

-- 7. 確認：7A9637ユーザーのデータが読み取れるかテスト
SELECT 
    '=== RLS修正後のデータ確認 ===' as info,
    user_id,
    date,
    daily_profit,
    base_amount,
    created_at
FROM user_daily_profit
WHERE user_id = '7A9637'
ORDER BY date DESC
LIMIT 5;

-- 8. 新しいポリシー確認
SELECT 
    '=== 修正後のRLSポリシー ===' as info,
    policyname,
    cmd,
    roles,
    qual
FROM pg_policies 
WHERE tablename = 'user_daily_profit';

COMMENT ON POLICY "authenticated_users_read_own_daily_profit" ON user_daily_profit IS 'ユーザーは自分の日利データを読み取り可能、管理者は全データアクセス可能';
COMMENT ON POLICY "anon_users_read_daily_profit" ON user_daily_profit IS '一時的：匿名ユーザーも読み取り可能（デバッグ用）';